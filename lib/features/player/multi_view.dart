import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/services/buffer_preset.dart';
import 'package:open_iptv/core/services/native_video_player.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/features/player/channel_switcher.dart';
import 'package:open_iptv/features/player/player_ui.dart';
import 'package:open_iptv/features/player/stream_watchdog.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/shared/widgets/video_surface.dart';
import 'package:open_iptv/ui/platform_helper.dart';

/// Several live channels on one screen (#52), started from the live
/// player's "Add a channel". The channel that was playing keeps playing in
/// the first tile on the app's main player (the [PlayerScreen] still runs
/// it, watchdog and all); every added channel gets its own muted native
/// player. Sound follows the highlighted tile.
///
/// The player screen keeps a [GlobalKey] to call [MultiViewState.leave] on
/// Back: the highlighted channel then plays full screen.
class MultiView extends StatefulWidget {
  const MultiView({
    super.key,
    required this.playbackService,
    required this.mainChannel,
    required this.firstAdded,
    required this.mainLoading,
    required this.mainMessage,
    required this.onSwapMain,
    required this.onRemoveMain,
    required this.onLeave,
  });

  final PlaybackService playbackService;

  /// The channel on the main player.
  final Channel mainChannel;
  final Channel firstAdded;

  /// The main player's state, from the player screen.
  final bool mainLoading;
  final String? mainMessage;

  /// Play another channel on the main player (Swap channel on its tile).
  final void Function(Channel channel) onSwapMain;

  /// The first tile was removed: stop the main player.
  final VoidCallback onRemoveMain;

  /// Leave multi-view, playing [channel] full screen. [onMainPlayer]: it's
  /// the channel already on the main player.
  final void Function(Channel channel, {required bool onMainPlayer}) onLeave;

  @override
  State<MultiView> createState() => MultiViewState();
}

enum _TileAction { fullScreen, swap, add, remove }

class MultiViewState extends State<MultiView> {
  late final List<_Tile> _tiles = [
    _Tile.main(widget.mainChannel, widget.playbackService),
    _Tile.extra(widget.firstAdded, widget.playbackService.bufferPreset, _changed),
  ];
  // The channel just added is the one you see highlighted and hear.
  int _highlight = 1;

  // Null = automatic (one big from 3 tiles, equal grid from 4).
  bool? _featured;
  bool get _isFeatured => _tiles.length >= 3 && (_featured ?? _tiles.length == 3);

  // Channel names show briefly after anything changes, then fade.
  bool _labels = true;
  Timer? _labelTimer;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    unawaited(_tiles[1].extra!.start());
    _applySound();
    _showLabels();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tiles[_highlight].node.requestFocus();
    });
  }

  @override
  void dispose() {
    _labelTimer?.cancel();
    for (final t in _tiles) {
      t.extra?.dispose();
      t.node.dispose();
    }
    // Whatever happens next, the main player is the one you hear again.
    unawaited(widget.playbackService.setAudible(true));
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _showLabels() {
    _labelTimer?.cancel();
    if (!_labels) setState(() => _labels = true);
    _labelTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _labels = false);
    });
  }

  // Sound (and audio focus) on the highlighted tile only.
  void _applySound() {
    for (var i = 0; i < _tiles.length; i++) {
      final t = _tiles[i];
      final on = i == _highlight;
      if (t.isMain) {
        unawaited(widget.playbackService.setAudible(on));
      } else {
        t.extra!.setAudible(on);
      }
    }
  }

  void _highlightTile(int i) {
    if (i == _highlight) return;
    setState(() => _highlight = i);
    _applySound();
    _showLabels();
  }

  /// Back: the highlighted channel full screen.
  void leave() {
    if (_left) return;
    _left = true;
    final t = _tiles[_highlight];
    widget.onLeave(t.channel, onMainPlayer: t.isMain);
  }

  Future<void> _openOptions(int i) async {
    _highlightTile(i);
    final t = _tiles[i];
    final action = await showPlayerSheet<_TileAction>(
      context,
      (ctx) => PlayerSheet(
        title: context.displayName(t.channel.name),
        children: [
          _OptionTile(
            icon: Icons.fullscreen_rounded,
            label: 'Full screen',
            autofocus: true,
            onTap: () => Navigator.pop(ctx, _TileAction.fullScreen),
          ),
          _OptionTile(
            icon: Icons.swap_horiz_rounded,
            label: 'Swap channel',
            onTap: () => Navigator.pop(ctx, _TileAction.swap),
          ),
          _OptionTile(
            icon: Icons.add_to_queue_rounded,
            label: 'Add a channel',
            onTap: () => Navigator.pop(ctx, _TileAction.add),
          ),
          if (_tiles.length >= 3)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: OptionRow<bool>(
                icon: Icons.dashboard_rounded,
                label: 'Layout',
                options: const [(false, 'Equal grid'), (true, 'One big')],
                selected: _isFeatured,
                onSelected: (featured) {
                  setState(() => _featured = featured);
                  Navigator.pop(ctx);
                },
              ),
            ),
          _OptionTile(
            icon: Icons.close_rounded,
            label: 'Remove',
            onTap: () => Navigator.pop(ctx, _TileAction.remove),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _TileAction.fullScreen:
        leave();
      case _TileAction.swap:
        await _swap(i);
      case _TileAction.add:
        await _add();
      case _TileAction.remove:
        _remove(i);
      case null:
        break;
    }
    if (mounted && !_left && _highlight < _tiles.length) {
      _tiles[_highlight].node.requestFocus();
    }
  }

  Future<void> _swap(int i) async {
    final t = _tiles[i];
    final picked = await showChannelSwitcher(context, t.channel.id);
    if (picked == null || !mounted || picked.id == t.channel.id) return;
    setState(() => t.channel = picked);
    if (t.isMain) {
      widget.onSwapMain(picked);
      _applySound();
    } else {
      t.extra!.tune(picked.streamUrl);
    }
    _showLabels();
  }

  Future<void> _add() async {
    final picked =
        await showChannelSwitcher(context, _tiles[_highlight].channel.id);
    if (picked == null || !mounted) return;
    final tile =
        _Tile.extra(picked, widget.playbackService.bufferPreset, _changed);
    setState(() {
      _tiles.add(tile);
      _highlight = _tiles.length - 1;
    });
    unawaited(tile.extra!.start());
    _applySound();
    _showLabels();
    // The new tile is the highlighted (and heard) one; the remote moves
    // there too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tile.node.requestFocus();
    });
  }

  void _remove(int i) {
    final t = _tiles[i];
    if (t.isMain) {
      // The main player belongs to the player screen: it stops, and the
      // tile goes.
      widget.onRemoveMain();
    } else {
      t.extra!.dispose();
    }
    setState(() {
      _tiles.removeAt(i);
      if (_highlight >= _tiles.length) _highlight = _tiles.length - 1;
    });
    t.node.dispose();
    if (_tiles.length == 1) {
      // One channel left: that's just the player.
      leave();
      return;
    }
    _applySound();
    _showLabels();
  }

  // --- keys -------------------------------------------------------------------

  // The tiles' current rectangles (set each layout), for D-pad moves.
  List<Rect> _laidOut = const [];

  KeyEventResult _onTileKey(int i, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      unawaited(_openOptions(i));
      return KeyEventResult.handled;
    }
    final dir = switch (key) {
      LogicalKeyboardKey.arrowLeft => const Offset(-1, 0),
      LogicalKeyboardKey.arrowRight => const Offset(1, 0),
      LogicalKeyboardKey.arrowUp => const Offset(0, -1),
      LogicalKeyboardKey.arrowDown => const Offset(0, 1),
      _ => null,
    };
    if (dir == null) return KeyEventResult.ignored;
    final next = multiViewNeighbour(_laidOut, i, dir);
    if (next != null) {
      _tiles[next].node.requestFocus();
      _highlightTile(next);
    }
    // At an edge nothing happens (and the key isn't passed on).
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tv = PlatformHelper.isTV(context);
    return ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(builder: (context, box) {
        final rects = multiViewLayout(box.biggest, _tiles.length,
            featured: _isFeatured);
        _laidOut = rects;
        return Stack(
          children: [
            for (var i = 0; i < _tiles.length; i++)
              AnimatedPositioned(
                key: ObjectKey(_tiles[i]),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: rects[i].left,
                top: rects[i].top,
                width: rects[i].width,
                height: rects[i].height,
                child: Focus(
                  focusNode: _tiles[i].node,
                  onFocusChange: (f) {
                    if (f) _highlightTile(i);
                  },
                  onKeyEvent: (_, e) => _onTileKey(i, e),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Phones: tap to hear a tile, tap it again for options.
                    onTap: () {
                      if (i == _highlight) {
                        unawaited(_openOptions(i));
                      } else {
                        _tiles[i].node.requestFocus();
                        _highlightTile(i);
                      }
                    },
                    child: _TileView(
                      tile: _tiles[i],
                      playbackService: widget.playbackService,
                      mainLoading: widget.mainLoading,
                      mainMessage: widget.mainMessage,
                      highlighted: i == _highlight,
                      showLabel: _labels,
                      tv: tv,
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// Where each of [n] tiles goes on a [size] screen: 2 side by side, then a
/// near-square grid (a short last row centred), or with [featured] one big
/// tile (two thirds wide) and the rest stacked beside it.
@visibleForTesting
List<Rect> multiViewLayout(Size size, int n, {required bool featured}) {
  const gap = 4.0;
  if (n <= 1) return [Offset.zero & size];
  if (featured && n >= 3) {
    final bigW = (size.width - gap) * 2 / 3;
    final smallW = size.width - gap - bigW;
    final smallH = (size.height - gap * (n - 2)) / (n - 1);
    return [
      Rect.fromLTWH(0, 0, bigW, size.height),
      for (var i = 0; i < n - 1; i++)
        Rect.fromLTWH(bigW + gap, i * (smallH + gap), smallW, smallH),
    ];
  }
  final cols = n == 2 ? 2 : math.sqrt(n).ceil();
  final rows = (n / cols).ceil();
  final w = (size.width - gap * (cols - 1)) / cols;
  final h = (size.height - gap * (rows - 1)) / rows;
  final rects = <Rect>[];
  for (var i = 0; i < n; i++) {
    final row = i ~/ cols;
    final inRow = row == rows - 1 ? n - row * cols : cols;
    final x0 = (size.width - (inRow * w + (inRow - 1) * gap)) / 2;
    final col = i % cols;
    rects.add(Rect.fromLTWH(x0 + col * (w + gap), row * (h + gap), w, h));
  }
  return rects;
}

/// The tile next to tile [i] in direction [dir] (unit offset): among the
/// tiles whose centre lies that way, the one that overlaps [i] most across
/// the move (the tile beside it, not one diagonally further), then the
/// nearest. Null at an edge.
@visibleForTesting
int? multiViewNeighbour(List<Rect> rects, int i, Offset dir) {
  if (i >= rects.length) return null;
  final from = rects[i];
  int? best;
  double bestOverlap = -1, bestDist = double.infinity;
  for (var j = 0; j < rects.length; j++) {
    if (j == i) continue;
    final r = rects[j];
    final d = r.center - from.center;
    final along = d.dx * dir.dx + d.dy * dir.dy;
    if (along <= 1) continue;
    final overlap = dir.dx != 0
        ? math.min(from.bottom, r.bottom) - math.max(from.top, r.top)
        : math.min(from.right, r.right) - math.max(from.left, r.left);
    if (overlap > bestOverlap + 1 ||
        ((overlap - bestOverlap).abs() <= 1 && along < bestDist)) {
      best = j;
      bestOverlap = overlap;
      bestDist = along;
    }
  }
  return best;
}

/// One tile: the main player's channel, or an added one with its own
/// player.
class _Tile {
  _Tile.main(this.channel, PlaybackService service)
      : isMain = true,
        extra = null,
        aspects = _aspects(service.stateStream);
  factory _Tile.extra(
      Channel channel, BufferPreset preset, VoidCallback onChange) {
    final extra = _ExtraPlayer(channel.streamUrl, preset, onChange);
    return _Tile._(channel, extra, _aspects(extra.stateStream));
  }
  _Tile._(this.channel, this.extra, this.aspects) : isMain = false;

  Channel channel;
  final bool isMain;
  final _ExtraPlayer? extra;
  // The picture's shape, only when it changes (state events come twice a
  // second).
  final Stream<double?> aspects;
  final FocusNode node = FocusNode(debugLabel: 'MultiViewTile');

  static Stream<double?> _aspects(Stream<NativeVideoPlayerState> states) =>
      states.map((s) => s.aspectRatio).distinct();
}

/// An added channel's own player, with its own freeze check and
/// plain-English messages.
class _ExtraPlayer {
  _ExtraPlayer(this._url, this.preset, this.onChange)
      : _dog = StreamWatchdog(
          freezeLimit: preset.freezeLimit,
          connectLimit: preset.connectLimit,
        );

  String _url;
  final BufferPreset preset;
  final VoidCallback onChange;
  final StreamWatchdog _dog;
  final NativeVideoPlayer _player = NativeVideoPlayer();

  int? textureId;
  NativeVideoPlayerState? last;
  String? message;
  bool get loading => message == null && _dog.loading;

  int _openCount = 0;
  bool _audible = false;
  bool _disposed = false;
  Timer? _timer;
  StreamSubscription<NativeVideoPlayerState>? _stateSub;
  StreamSubscription<NativePlaybackError>? _errorSub;

  Stream<NativeVideoPlayerState> get stateStream => _player.stateStream;

  Future<void> start() async {
    final id = await _player.create(audioFocus: false);
    if (_disposed) {
      await _player.dispose();
      return;
    }
    textureId = id;
    if (_audible) await _player.setAudible(true);
    _stateSub = _player.stateStream.listen((s) {
      last = s;
      _check();
    });
    _errorSub = _player.errorStream.listen(_onError);
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _check());
    await _open();
    onChange();
  }

  Future<void> _open() async {
    if (_disposed || textureId == null) return;
    _openCount++;
    await _player.open(_url,
        streamTypeHint: PlaybackService.streamTypeHint(_url),
        bufferPreset: preset.id);
    await _player.play();
  }

  void tune(String url) {
    _url = url;
    message = null;
    _dog.reset();
    unawaited(_open());
    onChange();
  }

  void setAudible(bool on) {
    if (on == _audible) return;
    _audible = on;
    if (textureId != null) unawaited(_player.setAudible(on));
  }

  void _check() {
    final s = last;
    if (_disposed || s == null || message != null) return;
    final wasLoading = _dog.loading;
    final action = _dog.check(s,
        now: DateTime.now(), openCount: _openCount, live: true);
    _act(action);
    if (wasLoading != _dog.loading) onChange();
  }

  void _onError(NativePlaybackError e) {
    if (_disposed || message != null) return;
    final code = e.code.toUpperCase();
    final http = e.httpStatus;
    if (code.contains('DECODER') || code.contains('DECODING')) {
      _fail("This device can't play another channel at the same time.");
    } else if (const {401, 403, 429, 458, 509, 551}.contains(http)) {
      _fail("Your provider didn't allow another stream.");
    } else if (e.isPermanent) {
      _fail("This channel isn't available right now.");
    } else {
      _act(_dog.onError(DateTime.now()));
    }
  }

  void _act(WatchdogAction action) {
    switch (action) {
      case WatchdogAction.reconnect:
        unawaited(_open());
      case WatchdogAction.giveUp:
        _fail("This channel isn't available right now.");
      case WatchdogAction.none:
        break;
    }
  }

  void _fail(String text) {
    message = text;
    // Free the provider connection.
    unawaited(_player.stop());
    onChange();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    unawaited(_stateSub?.cancel());
    unawaited(_errorSub?.cancel());
    if (textureId != null) unawaited(_player.dispose());
  }
}

class _TileView extends StatelessWidget {
  const _TileView({
    required this.tile,
    required this.playbackService,
    required this.mainLoading,
    required this.mainMessage,
    required this.highlighted,
    required this.showLabel,
    required this.tv,
  });

  final _Tile tile;
  final PlaybackService playbackService;
  final bool mainLoading;
  final String? mainMessage;
  final bool highlighted;
  final bool showLabel;
  final bool tv;

  @override
  Widget build(BuildContext context) {
    final extra = tile.extra;
    final int? textureId;
    final Stream<NativeVideoPlayerState> states;
    final double? knownAspect;
    final bool loading;
    final String? message;
    if (extra == null) {
      textureId = playbackService.hasTexture ? playbackService.textureId : null;
      states = playbackService.stateStream;
      knownAspect = playbackService.lastState.aspectRatio;
      loading = mainLoading;
      message = mainMessage;
    } else {
      textureId = extra.textureId;
      states = extra.stateStream;
      knownAspect = extra.last?.aspectRatio;
      loading = extra.loading;
      message = extra.message;
    }
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (textureId != null)
          VideoSurface(
            textureId: textureId,
            stateStream: states,
            initialAspectRatio: knownAspect,
          ),
        // Everything else follows the picture's own shape inside the tile
        // (the ring hugs the picture, not the black bars around it).
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) => StreamBuilder<double?>(
              stream: tile.aspects,
              builder: (context, snap) {
                final aspect = snap.data ?? knownAspect ?? 16 / 9;
                final rect = _pictureRect(box.biggest, aspect);
                return Stack(children: [
                  Positioned.fromRect(
                    rect: rect,
                    child: _overlays(context, theme, loading, message),
                  ),
                ]);
              },
            ),
          ),
        ),
      ],
    );
  }

  /// The letterboxed picture inside a [size] tile.
  static Rect _pictureRect(Size size, double aspect) {
    if (size.isEmpty || aspect <= 0) return Offset.zero & size;
    final fitted = applyBoxFit(BoxFit.contain, Size(aspect, 1), size);
    return Alignment.center.inscribe(fitted.destination, Offset.zero & size);
  }

  Widget _overlays(
          BuildContext context, ThemeData theme, bool loading, String? message) =>
      Stack(
        fit: StackFit.expand,
        children: [
          if (loading)
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white70),
              ),
            ),
          if (message != null)
            Container(
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!
                    .copyWith(color: Colors.white70),
              ),
            ),
          // Name along the bottom, shown for a few seconds after a change.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              opacity: showLabel || message != null ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xCC000000), Color(0x00000000)],
                  ),
                ),
                child: Text(
                  context.displayName(tile.channel.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall!.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          // The tile you hear.
          if (highlighted)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volume_up_rounded,
                    size: 18, color: Colors.white),
              ),
            ),
          // The other tiles are dimmed a little, so the highlighted one
          // stands out even on a bright, busy picture.
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              color: highlighted ? Colors.transparent : const Color(0x59000000),
            ),
          ),
          // Highlight ring around the picture: white, with a thin dark line
          // just inside it, so it shows on bright pictures too.
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: highlighted ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: tv ? 5 : 3),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0x99000000), width: 2),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TvActivatable(
        autofocus: autofocus,
        onTap: onTap,
        builder: (onTap) => ListTile(
          leading: Icon(icon),
          title: Text(label),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          onTap: onTap,
        ),
      );
}
