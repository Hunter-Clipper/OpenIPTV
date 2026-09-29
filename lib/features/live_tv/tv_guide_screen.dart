import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/providers/channel_providers.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/features/live_tv/catchup_launcher.dart';
import 'package:open_iptv/features/live_tv/guide_preview_controller.dart';
import 'package:open_iptv/shared/widgets/error_state_view.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';
import 'package:open_iptv/shared/widgets/video_surface.dart';

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

const _pxPerMinute = 4.0;
// Loaded once per screen open — generous enough to browse without needing
// to re-query on scroll. A dynamic "extend as you scroll" window is a
// reasonable fast-follow if real usage wants a wider range.
const _windowBefore = Duration(minutes: 30);
const _windowAfter = Duration(hours: 5, minutes: 30);
const _railWidth = 220.0;
const _rowHeight = 76.0;
const _minCellWidth = 90.0;

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

typedef _GuideWindow = ({
  List<String> channelIds,
  DateTime rangeStart,
  DateTime rangeEnd,
});

final _guideProgrammesProvider =
    FutureProvider.autoDispose.family<List<Programme>, _GuideWindow>(
  (ref, args) => ref
      .read(epgServiceProvider)
      .getProgrammesForChannelsInRange(
          args.channelIds, args.rangeStart, args.rangeEnd),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// TiviMate-style full-screen EPG grid: channel rail on the left, a
/// time-proportional programme timeline scrolling in sync across every row,
/// and a live mini-preview of whichever channel currently has focus.
class TvGuideScreen extends ConsumerStatefulWidget {
  const TvGuideScreen({super.key});

  @override
  ConsumerState<TvGuideScreen> createState() => _TvGuideScreenState();
}

class _TvGuideScreenState extends ConsumerState<TvGuideScreen> {
  late final DateTime _rangeStart;
  late final DateTime _rangeEnd;
  final _timeScrollController = ScrollController();
  // Wraps the grid so the D-pad handler can tell whether focus is still
  // inside the guide (vs. moved out to the nav rail).
  final _guideFocusNode =
      FocusNode(debugLabel: 'Guide', canRequestFocus: false, skipTraversal: true);
  Timer? _nowTicker;
  Timer? _previewDebounce;
  GuidePreviewController? _preview;
  // Cached so the provider family key keeps a stable identity across
  // rebuilds (1-min ticker, row focus). The record holds a List, which
  // compares by identity, so a freshly built key each build would create a
  // new provider — re-querying and blanking the grid. Replaced only when the
  // channel ids actually change.
  _GuideWindow? _window;
  List<Programme>? _groupedProgrammes;
  Map<String, List<Programme>> _byChannel = const {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Snap to the half hour so header ticks read 2:30 / 3:00 rather than
    // 2:47 / 3:17, and open scrolled to the slot containing "now" so the
    // programme already airing shows from its start (title visible) rather
    // than clipped at the left edge.
    final slotStart = DateTime(
        now.year, now.month, now.day, now.hour, now.minute < 30 ? 0 : 30);
    _rangeStart = slotStart.subtract(_windowBefore);
    _rangeEnd = slotStart.add(_windowAfter);
    _nowTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _timeScrollController.hasClients) {
        _timeScrollController.jumpTo(_windowBefore.inMinutes * _pxPerMinute);
      }
    });
  }

  @override
  void dispose() {
    _nowTicker?.cancel();
    _previewDebounce?.cancel();
    _preview?.dispose();
    _timeScrollController.dispose();
    _guideFocusNode.dispose();
    super.dispose();
  }

  void _onRowFocused(Channel channel) {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _preview ??= GuidePreviewController();
      setState(() {});
      _preview!.tune(channel.streamUrl).then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  Future<void> _selectCell(Channel channel, Programme programme) async {
    if (programme.isLive) {
      await _preview?.pause();
      if (!mounted) return;
      unawaited(context.push('/player', extra: {
        'streamUrl': channel.streamUrl,
        'title': channel.name,
        'contentType': 'live',
        'contentId': channel.id,
      }));
      return;
    }
    if (!programme.end.isBefore(DateTime.now())) return; // future — no-op
    if (!channel.hasCatchup) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Catch-up is not available for this programme.')));
      return;
    }
    final db = ref.read(appDatabaseProvider);
    final source = await db.getSourceById(channel.sourceId);
    if (source == null || !mounted) return;
    await _preview?.pause();
    if (!mounted) return;
    await launchCatchup(
      context: context,
      ref: ref,
      channel: channel,
      source: source,
      programme: programme,
      replace: false,
    );
  }

  // ---- Timeline scrolling (shared by header + all rows) ---------------

  double get _timelineMax => _timeScrollController.hasClients
      ? _timeScrollController.positions.first.maxScrollExtent
      : 0;

  double get _timelineOffset => _timeScrollController.hasClients
      ? _timeScrollController.positions.first.pixels
      : 0;

  void _stopTimelineScroll() {
    if (_timeScrollController.hasClients) {
      _timeScrollController.jumpTo(_timelineOffset);
    }
  }

  void _scrollTimelineBy(double dx) {
    if (!_timeScrollController.hasClients) return;
    _timeScrollController
        .jumpTo((_timelineOffset + dx).clamp(0.0, _timelineMax));
  }

  // A flick keeps gliding, like a normal scroll view: travel proportional
  // to release speed, easing out.
  void _flingTimeline(double velocity) {
    if (!_timeScrollController.hasClients || velocity.abs() < 100) return;
    final target =
        (_timelineOffset - velocity * 0.35).clamp(0.0, _timelineMax);
    _timeScrollController.animateTo(target,
        duration: const Duration(milliseconds: 450),
        curve: Curves.decelerate);
  }

  void _animateTimelineBy(double dx) {
    if (!_timeScrollController.hasClients) return;
    _timeScrollController.animateTo(
        (_timelineOffset + dx).clamp(0.0, _timelineMax),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut);
  }

  void _jumpToNow() {
    if (!_timeScrollController.hasClients) return;
    // Current half hour at the left edge, matching where the guide opens.
    final now = DateTime.now();
    final slot = DateTime(
        now.year, now.month, now.day, now.hour, now.minute < 30 ? 0 : 30);
    final x = slot.difference(_rangeStart).inMinutes * _pxPerMinute;
    _timeScrollController.animateTo(x.clamp(0.0, _timelineMax),
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  _GuideWindow _windowFor(List<Channel> channels) {
    final ids = [for (final c in channels) c.id];
    final current = _window;
    if (current != null && listEquals(current.channelIds, ids)) return current;
    return _window =
        (channelIds: ids, rangeStart: _rangeStart, rangeEnd: _rangeEnd);
  }

  Map<String, List<Programme>> _groupByChannel(List<Programme> programmes) {
    if (identical(programmes, _groupedProgrammes)) return _byChannel;
    final byChannel = <String, List<Programme>>{};
    for (final p in programmes) {
      (byChannel[p.channelId] ??= []).add(p);
    }
    _groupedProgrammes = programmes;
    return _byChannel = byChannel;
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(allChannelsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('TV Guide'),
        actions: [
          // After scrolling through the timeline, one tap gets back to what's
          // on now.
          TvActivatable(
            onTap: _jumpToNow,
            builder: (onTap) => TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.schedule),
              label: const Text('Now'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: channelsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(
          message: "Couldn't load the TV guide.",
          onRetry: () => ref.invalidate(allChannelsProvider),
        ),
        data: (channels) {
          if (channels.isEmpty) {
            return const Center(child: Text('No channels yet.'));
          }
          final programmes = ref
                  .watch(_guideProgrammesProvider(_windowFor(channels)))
                  .valueOrNull ??
              const <Programme>[];
          final byChannel = _groupByChannel(programmes);

          return Stack(
            children: [
              // Sideways drag anywhere on the guide scrolls the timeline for
              // the header and every row together. The rows' own scroll views
              // stay non-draggable (dragging one would pull it out of line
              // with the others); vertical drags still reach the channel list.
              Focus(
                focusNode: _guideFocusNode,
                canRequestFocus: false,
                skipTraversal: true,
                child: Actions(
                  actions: {
                    DirectionalFocusIntent: _GuideDirectionalAction(
                      guideFocusNode: _guideFocusNode,
                      scrollTimelineBy: (dx) => _animateTimelineBy(dx),
                      canScrollBack: () => _timelineOffset > 0.5,
                      parentContext: context,
                    ),
                  },
                  child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => _stopTimelineScroll(),
                onHorizontalDragUpdate: (d) => _scrollTimelineBy(-d.delta.dx),
                onHorizontalDragEnd: (d) =>
                    _flingTimeline(d.primaryVelocity ?? 0),
                child: Column(
                children: [
                  _TimeHeader(
                    rangeStart: _rangeStart,
                    scrollController: _timeScrollController,
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Stack(
                      children: [
                        ListView.builder(
                          itemCount: channels.length,
                          itemExtent: _rowHeight,
                          itemBuilder: (context, i) {
                            final channel = channels[i];
                            return _GuideRow(
                              // The remote starts on the first channel.
                              autofocus: i == 0,
                              channel: channel,
                              programmes: byChannel[channel.id] ?? const [],
                              rangeStart: _rangeStart,
                              rangeEnd: _rangeEnd,
                              scrollController: _timeScrollController,
                              onFocus: () => _onRowFocused(channel),
                              onSelect: (p) => _selectCell(channel, p),
                            );
                          },
                        ),
                        _NowLine(
                          rangeStart: _rangeStart,
                          scrollController: _timeScrollController,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ),
                ),
              ),
              // The preview tunes to whichever row has D-pad focus, which
              // only happens on TV; on touch it would just be an empty box
              // covering the grid.
              if (PlatformHelper.isTV(context))
                Positioned(
                  top: 12,
                  right: 12,
                  child: _PreviewPanel(preview: _preview),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time-axis header
// ---------------------------------------------------------------------------

class _TimeHeader extends StatelessWidget {
  const _TimeHeader({required this.rangeStart, required this.scrollController});

  final DateTime rangeStart;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMinutes =
        _windowBefore.inMinutes + _windowAfter.inMinutes;
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          const SizedBox(width: _railWidth),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: totalMinutes * _pxPerMinute,
                child: Stack(
                  children: [
                    for (var m = 0; m <= totalMinutes; m += 30)
                      Positioned(
                        left: m * _pxPerMinute,
                        top: 0,
                        bottom: 0,
                        child: Text(
                          _formatTime(rangeStart.add(Duration(minutes: m))),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }
}

// ---------------------------------------------------------------------------
// One channel row: rail cell + synced horizontal programme timeline
// ---------------------------------------------------------------------------

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.channel,
    required this.programmes,
    required this.rangeStart,
    required this.rangeEnd,
    required this.scrollController,
    required this.onFocus,
    required this.onSelect,
    this.autofocus = false,
  });

  final bool autofocus;
  final Channel channel;
  final List<Programme> programmes;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final ScrollController scrollController;
  final VoidCallback onFocus;
  final void Function(Programme) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalMinutes = rangeEnd.difference(rangeStart).inMinutes;

    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _railWidth,
            child: TvFocusable(
              autofocus: autofocus,
              ensureVisibleOnFocus: true,
              onTap: () {
                onFocus();
                onSelect(_currentOrFirst());
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.tv, size: 20,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              // Never independently draggable — see _ProgrammeCell, which
              // drives `scrollController` (shared by the header and every
              // row) programmatically on focus instead. A plain shared
              // ScrollController only synchronizes controller-level
              // animateTo/jumpTo calls across attached positions, not a
              // direct drag on one of them, so allowing drag here would let
              // one row scroll out of sync with the rest.
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: totalMinutes * _pxPerMinute,
                height: _rowHeight,
                child: Stack(
                  children: [
                    for (final p in programmes)
                      Positioned(
                        left: p.start.difference(rangeStart).inMinutes *
                            _pxPerMinute,
                        width: (p.duration.inMinutes * _pxPerMinute)
                            .clamp(_minCellWidth, double.infinity),
                        top: 4,
                        bottom: 4,
                        child: _ProgrammeCell(
                          programme: p,
                          hasCatchup: channel.hasCatchup,
                          left: p.start.difference(rangeStart).inMinutes *
                              _pxPerMinute,
                          scrollController: scrollController,
                          onFocus: onFocus,
                          onTap: () => onSelect(p),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Programme _currentOrFirst() {
    final now = DateTime.now();
    return programmes.firstWhere(
      (p) => p.isLive,
      orElse: () => programmes.isNotEmpty
          ? programmes.first
          : Programme(
              channelId: channel.id,
              start: now,
              end: now.add(const Duration(minutes: 30)),
              title: channel.name,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Programme cell
// ---------------------------------------------------------------------------

class _ProgrammeCell extends StatelessWidget {
  const _ProgrammeCell({
    required this.programme,
    required this.hasCatchup,
    required this.left,
    required this.scrollController,
    required this.onFocus,
    required this.onTap,
  });

  final Programme programme;
  final bool hasCatchup;
  // This cell's x offset within the shared horizontal scroll space —
  // dragging is disabled on every row's SingleChildScrollView (see
  // _GuideRow), so this is how a focused cell brings itself (and every
  // other row, since they share `scrollController`) into view instead.
  final double left;
  final ScrollController scrollController;
  final VoidCallback onFocus;
  final VoidCallback onTap;

  void _scrollIntoView() {
    if (!scrollController.hasClients) return;
    // The controller is shared by the header and every row, so
    // `.position` (which requires exactly one attachment) would throw;
    // they're all in sync, so any one of them gives the extent.
    final target = left.clamp(
        0.0, scrollController.positions.first.maxScrollExtent);
    scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = programme.isLive;
    final isPast = programme.end.isBefore(DateTime.now());
    final progress = programme.progressAt(DateTime.now());

    final cellChild = Container(
      decoration: BoxDecoration(
        color: isLive
            ? theme.colorScheme.primary.withValues(alpha: 0.18)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  programme.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall!.copyWith(
                    color: isPast && !isLive
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                    fontWeight: isLive ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (isPast && !isLive && hasCatchup)
                Icon(Icons.replay_circle_filled_outlined,
                    size: 12, color: theme.colorScheme.primary),
            ],
          ),
          if (isLive) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 2,
                backgroundColor: theme.colorScheme.surface,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TvFocusable(
        onTap: onTap,
        onFocusChange: (has) {
          if (has) {
            onFocus();
            _scrollIntoView();
          }
        },
        child: cellChild,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Now" cursor line
// ---------------------------------------------------------------------------

/// Red "now" marker over the programme grid. Must be a direct Stack child
/// (it's a Positioned — wrapping it, e.g. in IgnorePointer, throws and
/// blanks the whole guide). Tracks the grid's horizontal scroll so it stays
/// on the current time, and hides while that time is scrolled under the
/// channel rail.
class _NowLine extends StatelessWidget {
  const _NowLine({required this.rangeStart, required this.scrollController});

  final DateTime rangeStart;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final minutesFromStart = DateTime.now().difference(rangeStart).inMinutes;
    final color = Theme.of(context).colorScheme.error;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: scrollController,
          builder: (context, _) {
            // Shared controller (header + every row) — `.offset` would
            // throw with several attached; they're in sync, so use any.
            final offset = scrollController.hasClients
                ? scrollController.positions.first.pixels
                : 0.0;
            final left =
                _railWidth + minutesFromStart * _pxPerMinute - offset;
            if (left < _railWidth) return const SizedBox.shrink();
            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  width: 2,
                  child: ColoredBox(color: color),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini live-preview panel
// ---------------------------------------------------------------------------

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.preview});

  final GuidePreviewController? preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 135,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: preview?.textureId == null
          ? const Center(
              child: Icon(Icons.live_tv, color: Colors.white54, size: 32))
          : VideoSurface(
              textureId: preview!.textureId!,
              stateStream: preview!.stateStream,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// D-pad handling
// ---------------------------------------------------------------------------

/// Left/Right in the guide move along the current row. Flutter's default
/// directional focus falls back to the *closest* candidate, which in a grid
/// is often a diagonal jump into another row — and a channel with no guide
/// data has no cells at all. In both cases this keeps focus in its row and
/// scrolls the timeline by half an hour instead, so the remote can always
/// move through time. Up/Down, and Left out to the nav rail, are unchanged.
class _GuideDirectionalAction extends Action<DirectionalFocusIntent> {
  _GuideDirectionalAction({
    required this.guideFocusNode,
    required this.scrollTimelineBy,
    required this.canScrollBack,
    required this.parentContext,
  });

  final FocusNode guideFocusNode;
  final void Function(double dx) scrollTimelineBy;
  // Whether the timeline is scrolled forward at all — Left goes back in time
  // first and only leaves the guide once at the start.
  final bool Function() canScrollBack;
  // Above this Action, so Up/Down reach the shell's own handler.
  final BuildContext parentContext;

  static const _step = 30 * _pxPerMinute;

  @override
  Object? invoke(DirectionalFocusIntent intent) {
    final dir = intent.direction;
    final before = primaryFocus;
    final horizontal =
        dir == TraversalDirection.left || dir == TraversalDirection.right;
    if (before == null || !horizontal) {
      return Actions.maybeInvoke(parentContext, intent);
    }
    final from = before.rect;
    final scroll = dir == TraversalDirection.right ? _step : -_step;
    // Nothing more to move through: Left at the start of the timeline goes
    // to the shell (which moves focus to the nav rail); otherwise scroll.
    void cannotMove() {
      if (dir == TraversalDirection.left && !canScrollBack()) {
        Actions.maybeInvoke(parentContext, intent);
      } else {
        scrollTimelineBy(scroll);
      }
    }

    if (!before.focusInDirection(dir)) {
      cannotMove();
      return true;
    }
    // Focus changes apply a moment later — judge where it actually landed.
    scheduleMicrotask(() {
      final after = primaryFocus;
      if (after == null) return;
      // focusInDirection can report success yet leave focus where it was
      // (nothing further that way) — treat that as "couldn't move".
      if (identical(after, before)) {
        cannotMove();
        return;
      }
      final sameRow =
          (after.rect.center.dy - from.center.dy).abs() < from.height / 2;
      if (sameRow && guideFocusNode.hasFocus) return; // along the row
      // Left out of the guide (to the nav rail or Back) is a real exit —
      // once the timeline is back at its start.
      final exitedLeft = dir == TraversalDirection.left &&
          !guideFocusNode.hasFocus &&
          after.rect.center.dx < from.left;
      if (exitedLeft && !canScrollBack()) return;
      // A diagonal jump into another row, or up to the app bar: stay put
      // and move through time instead.
      before.requestFocus();
      scrollTimelineBy(scroll);
    });
    return true;
  }
}
