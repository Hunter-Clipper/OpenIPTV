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
    _rangeStart = now.subtract(_windowBefore);
    _rangeEnd = now.add(_windowAfter);
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
      appBar: AppBar(title: const Text('TV Guide')),
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
              Column(
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
                        IgnorePointer(
                          child: _NowLine(rangeStart: _rangeStart),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
  });

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
    final target =
        left.clamp(0.0, scrollController.position.maxScrollExtent);
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

class _NowLine extends StatelessWidget {
  const _NowLine({required this.rangeStart});

  final DateTime rangeStart;

  @override
  Widget build(BuildContext context) {
    final minutesFromStart = DateTime.now().difference(rangeStart).inMinutes;
    return Positioned(
      left: _railWidth + minutesFromStart * _pxPerMinute,
      top: 0,
      bottom: 0,
      width: 2,
      child: Container(color: Theme.of(context).colorScheme.error),
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
          : Texture(textureId: preview!.textureId!),
    );
  }
}
