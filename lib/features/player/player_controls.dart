import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/native_video_player.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/features/live_tv/epg_panel.dart';
import 'package:open_iptv/shared/utils/format.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

/// Overlay controls for the full-screen player.
/// Supports both Live TV and VOD (movie / episode) modes.
class PlayerControls extends ConsumerStatefulWidget {
  const PlayerControls({
    super.key,
    required this.title,
    required this.isLive,
    this.contentType,
    this.contentId,
    this.isLiveDvr = false,
    this.onLivePlayPause,
    this.onLiveRewind,
    this.onLiveForward,
    this.onGoLive,
    this.isBehindLive = false,
    this.playPauseFocusNode,
    this.backFocusNode,
  });

  final String title;
  final bool isLive;
  final String? contentType;
  final String? contentId;
  // Focus lands here whenever PlayerScreen reveals the controls (initial
  // show, tap-to-show, or pressing select/OK while hidden) so the D-pad can
  // immediately navigate from a sensible starting point.
  final FocusNode? playPauseFocusNode;
  // Lets PlayerScreen's edge-aware "Up" fallback request focus here directly
  // when Flutter's own directional traversal finds nothing above whatever's
  // currently focused (e.g. the centered play/pause button has no candidate
  // overlapping it horizontally, even though this screen-edge Back button is
  // clearly the intended target).
  final FocusNode? backFocusNode;
  // True while a catch-up-enabled live channel has been switched into full
  // DVR scrubbing (real seek bar via _VodControls) by the user pausing or
  // rewinding — as opposed to a programme picked from the EPG guide.
  final bool isLiveDvr;
  final VoidCallback? onLivePlayPause;
  final VoidCallback? onLiveRewind;
  final VoidCallback? onLiveForward;
  // Jumps back to the true live edge — from local-buffer rewind on a
  // non-catch-up channel, or out of DVR mode on a catch-up one.
  final VoidCallback? onGoLive;
  final bool isBehindLive;

  @override
  ConsumerState<PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends ConsumerState<PlayerControls> {
  StreamSubscription<NativeVideoPlayerState>? _stateSub;
  StreamSubscription<List<NativeVideoTrack>>? _tracksSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _videoHeight = 0;
  List<NativeVideoTrack> _tracks = const [];
  bool _isSeeking = false;
  double _seekValue = 0;

  bool get _hasSubtitles => _tracks.any((t) => t.type == 'text');

  bool get _ccActive => _tracks.any((t) => t.type == 'text' && t.selected);

  String? get _qualityLabel {
    final h = _videoHeight;
    if (h == 0) return null;
    if (h >= 2160) return '4K';
    if (h >= 1080) return 'FHD';
    if (h >= 720) return 'HD';
    return 'SD';
  }

  @override
  void initState() {
    super.initState();
    final service = ref.read(playbackServiceProvider);
    final initial = service.lastState;
    _position = initial.position;
    _duration = initial.duration;
    _videoHeight = initial.videoHeight;
    _stateSub = service.stateStream.listen((s) {
      if (!mounted) return;
      setState(() {
        if (!_isSeeking) _position = s.position;
        _duration = s.duration;
        _videoHeight = s.videoHeight;
      });
    });
    _tracksSub = service.tracksStream.listen((t) {
      if (mounted) setState(() => _tracks = t);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _tracksSub?.cancel();
    super.dispose();
  }

  Future<void> _seek(Duration target) async {
    await ref.read(playbackServiceProvider).seek(target);
  }

  Future<void> _seekRelative(Duration delta) async {
    await ref.read(playbackServiceProvider).seekRelative(delta);
  }

  /// User-facing name for a subtitle/CC track: its own label, else its
  /// language, else the caption channel ("CC1"), else a numbered fallback.
  /// Numbered by position when several tracks would otherwise read the same.
  static String _trackLabel(
      NativeVideoTrack t, int index, List<NativeVideoTrack> all) {
    String base(NativeVideoTrack t) {
      if (t.label.isNotEmpty) return t.label;
      if (t.language?.isNotEmpty == true && t.language != 'und') {
        return t.language!.toUpperCase();
      }
      final mime = t.mimeType ?? '';
      // Broadcast captions: CEA-608 channel 1 / CEA-708 service 1 are the
      // primary (almost always English) track; higher numbers are extras.
      if (mime.contains('608')) {
        return t.channel > 1 ? 'Captions ${t.channel}' : 'Captions';
      }
      if (mime.contains('708')) {
        return t.channel > 1 ? 'Digital captions ${t.channel}' : 'Digital captions';
      }
      return 'Subtitles';
    }

    final name = base(t);
    final duplicated = all.where((o) => base(o) == name).length > 1;
    return duplicated ? '$name ${index + 1}' : name;
  }

  void _showCcPicker(BuildContext context) {
    final realTracks = _tracks.where((t) => t.type == 'text').toList();
    if (realTracks.isEmpty && widget.isLive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subtitles detected for this channel'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text('Subtitles / CC',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.subtitles_off_outlined),
                title: const Text('Off'),
                selected: !_ccActive,
                onTap: () {
                  ref.read(playbackServiceProvider).clearTextTrack();
                  Navigator.of(ctx).pop();
                },
              ),
              ...realTracks.indexed.map((e) {
                final (i, t) = e;
                final label = _trackLabel(t, i, realTracks);
                return ListTile(
                  leading: const Icon(Icons.subtitles_outlined),
                  title: Text(label),
                  selected: t.selected,
                  onTap: () {
                    ref.read(playbackServiceProvider).selectTrack(t.id);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showEpgPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EpgPanel(
        channelId: widget.contentId ?? '',
        channelName: widget.title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.isLive
        ? _LiveControls(
            title: widget.title,
            contentId: widget.contentId,
            qualityLabel: _qualityLabel,
            hasCc: _hasSubtitles,
            ccActive: _ccActive,
            onBack: () => context.pop(),
            onEpg: () => _showEpgPanel(context),
            onCc: () => _showCcPicker(context),
            onPlayPause: widget.onLivePlayPause,
            onRewind: widget.onLiveRewind,
            onForward: widget.onLiveForward,
            onGoLive: widget.onGoLive,
            isBehindLive: widget.isBehindLive,
            playPauseFocusNode: widget.playPauseFocusNode,
            backFocusNode: widget.backFocusNode,
          )
        : _VodControls(
            title: widget.title,
            qualityLabel: _qualityLabel,
            hasCc: _hasSubtitles,
            ccActive: _ccActive,
            position: _position,
            duration: _duration,
            isSeeking: _isSeeking,
            seekValue: _seekValue,
            onBack: () => context.pop(),
            onCc: () => _showCcPicker(context),
            onSeekStart: () => setState(() => _isSeeking = true),
            onSeekUpdate: (v) => setState(() => _seekValue = v),
            onSeekEnd: (v) {
              setState(() {
                _isSeeking = false;
                _seekValue = v;
              });
              final target = Duration(
                  milliseconds: (v * _duration.inMilliseconds).round());
              _seek(target);
            },
            onSkipBack: () =>
                _seekRelative(const Duration(seconds: -10)),
            onSkipForward: () =>
                _seekRelative(const Duration(seconds: 10)),
            onEpg: widget.contentType == 'catchup'
                ? () => _showEpgPanel(context)
                : null,
            contentId:
                widget.contentType == 'catchup' ? widget.contentId : null,
            onGoLive: widget.isLiveDvr ? widget.onGoLive : null,
            playPauseFocusNode: widget.playPauseFocusNode,
            backFocusNode: widget.backFocusNode,
          );
  }
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------
//
// Both modes share one layout, modelled on YouTube TV's player:
//   - top-left Back, top-right quality badge;
//   - transport (rewind / play-pause / forward) centred on the whole screen,
//     not just the space left between the bars;
//   - bottom-left title block over a full-width progress bar, with a meta
//     line (LIVE / times) on the left and round action buttons on the right.

/// Sizes scale up for TV (viewed from across the room) and down for phones.
class _Metrics {
  const _Metrics._(this.scale);

  factory _Metrics.of(BuildContext context) {
    if (PlatformHelper.isTV(context)) return const _Metrics._(1.15);
    final short = MediaQuery.sizeOf(context).shortestSide;
    return _Metrics._(short < 500 ? 0.85 : 1.0);
  }

  final double scale;

  double get edge => 32 * scale;
  double get playSize => 72 * scale;
  double get skipSize => 56 * scale;
  double get actionSize => 44 * scale;
  double get transportGap => 32 * scale;
  double get titleSize => 22 * scale;
  double get bodySize => 14 * scale;
}

class _ControlsLayout extends StatelessWidget {
  const _ControlsLayout({
    required this.onBack,
    required this.backFocusNode,
    required this.qualityLabel,
    required this.transport,
    required this.bottom,
    this.background,
  });

  final VoidCallback onBack;
  final FocusNode? backFocusNode;
  final String? qualityLabel;
  final Widget? transport;
  final Widget bottom;
  // Painted beneath the controls, above the scrim (e.g. VOD double-tap
  // seek zones).
  final Widget? background;

  @override
  Widget build(BuildContext context) {
    final m = _Metrics.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xB3000000),
                Colors.transparent,
                Colors.transparent,
                Color(0xE6000000),
              ],
              stops: [0.0, 0.22, 0.5, 1.0],
            ),
          ),
        ),
        if (background != null) background!,
        if (transport != null) Center(child: transport),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            minimum: EdgeInsets.fromLTRB(m.edge, m.edge / 2, m.edge, 0),
            child: Row(
              children: [
                _PlayerButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back',
                  onTap: onBack,
                  focusNode: backFocusNode,
                  size: m.actionSize,
                ),
                const Spacer(),
                if (qualityLabel != null) _QualityBadge(label: qualityLabel!),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(m.edge, 0, m.edge, m.edge * 0.75),
            child: bottom,
          ),
        ),
      ],
    );
  }
}

/// Title block + progress bar + meta/actions row.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.title,
    required this.bar,
    required this.meta,
    required this.actions,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget bar;
  final Widget meta;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final m = _Metrics.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: m.titleSize,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          SizedBox(height: 4 * m.scale),
          Text(
            subtitle!,
            style: TextStyle(
              color: Colors.white70,
              fontSize: m.bodySize + 1,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        SizedBox(height: 12 * m.scale),
        bar,
        SizedBox(height: 8 * m.scale),
        Row(
          children: [
            Expanded(child: meta),
            for (final a in actions) ...[
              SizedBox(width: 8 * m.scale),
              a,
            ],
          ],
        ),
      ],
    );
  }
}

/// Rewind / play-pause / forward, centred as one group.
class _Transport extends ConsumerWidget {
  const _Transport({
    required this.onPlayPause,
    required this.onRewind,
    required this.onForward,
    this.playPauseFocusNode,
  });

  final VoidCallback onPlayPause;
  final VoidCallback onRewind;
  final VoidCallback onForward;
  final FocusNode? playPauseFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = _Metrics.of(context);
    final service = ref.watch(playbackServiceProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PlayerButton(
          icon: Icons.replay_10,
          tooltip: 'Back 10 seconds',
          onTap: onRewind,
          size: m.skipSize,
          filled: true,
        ),
        SizedBox(width: m.transportGap),
        StreamBuilder<NativeVideoPlayerState>(
          stream: service.stateStream,
          initialData: service.lastState,
          builder: (context, snap) {
            final playing = snap.data?.playing ?? false;
            return _PlayerButton(
              icon: playing ? Icons.pause : Icons.play_arrow,
              tooltip: playing ? 'Pause' : 'Play',
              onTap: onPlayPause,
              focusNode: playPauseFocusNode,
              size: m.playSize,
              filled: true,
            );
          },
        ),
        SizedBox(width: m.transportGap),
        _PlayerButton(
          icon: Icons.forward_10,
          tooltip: 'Forward 10 seconds',
          onTap: onForward,
          size: m.skipSize,
          filled: true,
        ),
      ],
    );
  }
}

/// CC / favourite / guide buttons shared by both modes.
List<Widget> _actionButtons({
  required BuildContext context,
  required WidgetRef ref,
  required bool showCc,
  required bool hasCc,
  required bool ccActive,
  required VoidCallback onCc,
  required String? favoriteChannelId,
  required VoidCallback? onEpg,
}) {
  final m = _Metrics.of(context);
  final profile = ref.watch(activeProfileProvider).valueOrNull;
  final isFav = profile?.favoriteChannelIds.contains(favoriteChannelId) ?? false;
  return [
    // Live CC stays visible even with no tracks yet — embedded CEA-608/708
    // captions can appear late — but dims until some are detected.
    if (showCc)
      _PlayerButton(
        icon: ccActive ? Icons.closed_caption : Icons.closed_caption_outlined,
        tooltip: 'Subtitles / CC',
        onTap: onCc,
        size: m.actionSize,
        dimmed: !hasCc && !ccActive,
        active: ccActive,
      ),
    if (favoriteChannelId != null && profile != null)
      _PlayerButton(
        icon: isFav ? Icons.star : Icons.star_border,
        tooltip: isFav ? 'Remove from Favorites' : 'Add to Favorites',
        onTap: () async {
          await ref
              .read(profileServiceProvider)
              .toggleFavoriteChannel(profile.id, favoriteChannelId);
          // The profile provider caches favorites; refresh so the star
          // (and the channel lists behind the player) reflect the change.
          if (context.mounted) ref.invalidate(activeProfileProvider);
        },
        size: m.actionSize,
        active: isFav,
      ),
    if (onEpg != null)
      _PlayerButton(
        icon: Icons.view_list_rounded,
        tooltip: 'TV Guide',
        onTap: onEpg,
        size: m.actionSize,
      ),
  ];
}

// ---------------------------------------------------------------------------
// Live TV controls
// ---------------------------------------------------------------------------

class _LiveControls extends ConsumerWidget {
  const _LiveControls({
    required this.title,
    required this.contentId,
    required this.onBack,
    required this.onEpg,
    required this.onCc,
    required this.hasCc,
    required this.ccActive,
    this.qualityLabel,
    this.onPlayPause,
    this.onRewind,
    this.onForward,
    this.onGoLive,
    this.isBehindLive = false,
    this.playPauseFocusNode,
    this.backFocusNode,
  });

  final String title;
  final String? contentId;
  final String? qualityLabel;
  final bool hasCc;
  final bool ccActive;
  final VoidCallback onBack;
  final VoidCallback onEpg;
  final VoidCallback onCc;
  final VoidCallback? onPlayPause;
  final VoidCallback? onRewind;
  final VoidCallback? onForward;
  final VoidCallback? onGoLive;
  final bool isBehindLive;
  final FocusNode? playPauseFocusNode;
  final FocusNode? backFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = _actionButtons(
      context: context,
      ref: ref,
      showCc: true,
      hasCc: hasCc,
      ccActive: ccActive,
      onCc: onCc,
      favoriteChannelId: contentId,
      onEpg: onEpg,
    );
    // LIVE badge doubles as a "back to live" button once the user has
    // paused/rewound behind the live edge.
    final liveBadge = isBehindLive && onGoLive != null
        ? TvFocusable(
            onTap: onGoLive!,
            borderRadius: BorderRadius.circular(6),
            child: const _LiveBadge(isBehindLive: true),
          )
        : const _LiveBadge(isBehindLive: false);

    return _ControlsLayout(
      onBack: onBack,
      backFocusNode: backFocusNode,
      qualityLabel: qualityLabel,
      transport: onPlayPause == null
          ? null
          : _Transport(
              onPlayPause: onPlayPause!,
              onRewind: onRewind!,
              onForward: onForward!,
              playPauseFocusNode: playPauseFocusNode,
            ),
      bottom: contentId == null
          ? _BottomPanel(
              title: title,
              bar: const _ProgressBar(value: 1),
              meta: liveBadge,
              actions: actions,
            )
          : _LiveProgrammePanel(
              channelId: contentId!,
              channelName: title,
              liveBadge: liveBadge,
              actions: actions,
            ),
    );
  }
}

class _LiveProgrammePanel extends ConsumerStatefulWidget {
  const _LiveProgrammePanel({
    required this.channelId,
    required this.channelName,
    required this.liveBadge,
    required this.actions,
  });

  final String channelId;
  final String channelName;
  final Widget liveBadge;
  final List<Widget> actions;

  @override
  ConsumerState<_LiveProgrammePanel> createState() =>
      _LiveProgrammePanelState();
}

class _LiveProgrammePanelState extends ConsumerState<_LiveProgrammePanel> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  // Held in state rather than built in build() — the parent rebuilds on
  // every player state event, which would otherwise re-query the EPG
  // several times a second.
  late Future<Programme?> _programme;

  @override
  void initState() {
    super.initState();
    _programme = _fetchProgramme();
    // Refresh the progress position (and the current programme, in case it
    // has rolled over) every 30 seconds.
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
        _programme = _fetchProgramme();
      });
    });
  }

  @override
  void didUpdateWidget(covariant _LiveProgrammePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) {
      _programme = _fetchProgramme();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<Programme?> _fetchProgramme() =>
      ref.read(epgServiceProvider).getCurrentProgramme(widget.channelId);

  String _time(BuildContext context, DateTime t) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(t),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  @override
  Widget build(BuildContext context) {
    final m = _Metrics.of(context);
    return FutureBuilder<Programme?>(
      future: _programme,
      builder: (context, snapshot) {
        final prog = snapshot.data;
        final metaStyle =
            TextStyle(color: Colors.white70, fontSize: m.bodySize);
        return _BottomPanel(
          // Programme title leads when known (what's on), channel below —
          // same hierarchy as YouTube TV.
          title: prog?.title ?? widget.channelName,
          subtitle: prog == null ? null : widget.channelName,
          bar: _ProgressBar(value: prog?.progressAt(_now) ?? 1),
          meta: Row(
            children: [
              widget.liveBadge,
              if (prog != null) ...[
                SizedBox(width: 12 * m.scale),
                Flexible(
                  child: Text(
                    '${_time(context, prog.start)} – ${_time(context, prog.end)}'
                    '  ·  ${formatRuntime(prog.end.difference(_now))} left',
                    style: metaStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          actions: widget.actions,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// VOD controls
// ---------------------------------------------------------------------------

class _VodControls extends ConsumerWidget {
  const _VodControls({
    required this.title,
    required this.position,
    required this.duration,
    required this.isSeeking,
    required this.seekValue,
    required this.onBack,
    required this.onCc,
    required this.hasCc,
    required this.ccActive,
    required this.onSeekStart,
    required this.onSeekUpdate,
    required this.onSeekEnd,
    required this.onSkipBack,
    required this.onSkipForward,
    this.qualityLabel,
    this.onEpg,
    this.contentId,
    this.onGoLive,
    this.playPauseFocusNode,
    this.backFocusNode,
  });

  final String title;
  final String? qualityLabel;
  final FocusNode? playPauseFocusNode;
  final FocusNode? backFocusNode;
  // Only set for catch-up playback — the channel id, reused so the
  // favourite toggle applies to the channel, same as live playback.
  final String? contentId;
  final bool hasCc;
  final bool ccActive;
  final Duration position;
  final Duration duration;
  final bool isSeeking;
  final double seekValue;
  final VoidCallback onBack;
  final VoidCallback onCc;
  final VoidCallback onSeekStart;
  final void Function(double) onSeekUpdate;
  final void Function(double) onSeekEnd;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  // Only set for catch-up playback — lets the user get back to the guide
  // (browse other times, or jump back to live) without exiting the player.
  final VoidCallback? onEpg;
  // Only set when a live channel was switched into DVR scrubbing (pause/
  // rewind from _LiveControls) — jumps back to the true live edge.
  final VoidCallback? onGoLive;

  double get _sliderValue {
    if (isSeeking) return seekValue;
    if (duration.inMilliseconds == 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = _Metrics.of(context);
    final service = ref.watch(playbackServiceProvider);
    final shownPosition = isSeeking
        ? Duration(milliseconds: (seekValue * duration.inMilliseconds).round())
        : position;

    return _ControlsLayout(
      onBack: onBack,
      backFocusNode: backFocusNode,
      qualityLabel: qualityLabel,
      // Invisible double-tap seek zones for touch (left half back, right
      // half forward); D-pad users get the focusable transport buttons.
      background: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: onSkipBack,
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: onSkipForward,
            ),
          ),
        ],
      ),
      transport: _Transport(
        onPlayPause: service.togglePlayPause,
        onRewind: onSkipBack,
        onForward: onSkipForward,
        playPauseFocusNode: playPauseFocusNode,
      ),
      bottom: _BottomPanel(
        title: title,
        bar: SizedBox(
          height: 20 * m.scale,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4 * m.scale,
              thumbShape:
                  RoundSliderThumbShape(enabledThumbRadius: 7 * m.scale),
              overlayShape:
                  RoundSliderOverlayShape(overlayRadius: 16 * m.scale),
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
              trackShape: const _EdgeToEdgeTrackShape(),
            ),
            child: Slider(
              value: _sliderValue,
              onChangeStart: (_) => onSeekStart(),
              onChanged: onSeekUpdate,
              onChangeEnd: onSeekEnd,
            ),
          ),
        ),
        meta: Row(
          children: [
            if (onGoLive != null) ...[
              TvFocusable(
                onTap: onGoLive!,
                borderRadius: BorderRadius.circular(6),
                child: const _LiveBadge(isBehindLive: true),
              ),
              SizedBox(width: 12 * m.scale),
            ],
            Text(
              duration.inSeconds > 0
                  ? '${formatClock(shownPosition)} / ${formatClock(duration)}'
                  : formatClock(shownPosition),
              style: TextStyle(
                color: Colors.white70,
                fontSize: m.bodySize,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        actions: _actionButtons(
          context: context,
          ref: ref,
          showCc: hasCc,
          hasCc: hasCc,
          ccActive: ccActive,
          onCc: onCc,
          favoriteChannelId: contentId,
          onEpg: onEpg,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

/// Round, D-pad-focusable player button. Focus follows the YouTube TV
/// convention: the button fills white with a dark icon and grows slightly,
/// rather than the generic accent ring used elsewhere in the app.
class _PlayerButton extends StatefulWidget {
  const _PlayerButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.size,
    this.focusNode,
    this.filled = false,
    this.active = false,
    this.dimmed = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final FocusNode? focusNode;
  // Floats over the picture (the centred transport), where the scrim is
  // clear: a dark translucent disc keeps it legible over bright video.
  final bool filled;
  // On-state (CC on, favourited): icon in the accent colour.
  final bool active;
  // Available but nothing to show yet (CC with no tracks detected).
  final bool dimmed;

  @override
  State<_PlayerButton> createState() => _PlayerButtonState();
}

class _PlayerButtonState extends State<_PlayerButton> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    // Focus highlight only on TV, matching TvFocusable's ring — on touch
    // devices the play button holds focus after reveal and would otherwise
    // look permanently selected.
    final lit = _focused && PlatformHelper.isTV(context);
    final accent = Theme.of(context).colorScheme.primary;
    final Color bg;
    if (lit) {
      bg = Colors.white;
    } else if (_hovered) {
      bg = Colors.white.withValues(alpha: 0.24);
    } else if (widget.filled) {
      bg = Colors.black.withValues(alpha: 0.45);
    } else {
      bg = Colors.transparent;
    }
    final Color fg;
    if (lit) {
      fg = Colors.black;
    } else if (widget.active) {
      fg = accent;
    } else if (widget.dimmed) {
      fg = Colors.white38;
    } else {
      fg = Colors.white;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: TvFocusable(
        onTap: widget.onTap,
        focusNode: widget.focusNode,
        showFocusRing: false,
        onFocusChange: (f) => setState(() => _focused = f),
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedScale(
            scale: lit ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(widget.icon, color: fg, size: widget.size * 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin, rounded, non-interactive progress bar (live programme progress).
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final m = _Metrics.of(context);
    return SizedBox(
      height: 20 * m.scale,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2 * m.scale),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 4 * m.scale,
            backgroundColor: Colors.white24,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Slider track that spans the full width, so the seek bar lines up with
/// the title and meta row instead of being inset by the thumb radius.
class _EdgeToEdgeTrackShape extends RoundedRectSliderTrackShape {
  const _EdgeToEdgeTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final height = sliderTheme.trackHeight ?? 4;
    final top = offset.dy + (parentBox.size.height - height) / 2;
    return Rect.fromLTWH(offset.dx, top, parentBox.size.width, height);
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isBehindLive});

  // Behind the live edge: grey "Go live" pill instead of the red dot.
  final bool isBehindLive;

  @override
  Widget build(BuildContext context) {
    final m = _Metrics.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 10 * m.scale, vertical: 4 * m.scale),
      decoration: BoxDecoration(
        color: isBehindLive ? Colors.white24 : const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isBehindLive)
            Icon(Icons.skip_next_rounded, color: Colors.white, size: 14 * m.scale)
          else
            Container(
              width: 6 * m.scale,
              height: 6 * m.scale,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
          SizedBox(width: 6 * m.scale),
          Text(
            isBehindLive ? 'GO LIVE' : 'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12 * m.scale,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityBadge extends StatelessWidget {
  const _QualityBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final m = _Metrics.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 8 * m.scale, vertical: 3 * m.scale),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white38),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11 * m.scale,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
