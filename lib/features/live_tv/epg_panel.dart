import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/parsers/xtream_client.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';

/// Slide-up panel widget showing the EPG schedule for a single channel.
///
/// Designed to be shown as a bottom sheet (e.g. via showModalBottomSheet),
/// but can also be embedded directly in a Stack for player overlays.
class EpgPanel extends ConsumerStatefulWidget {
  const EpgPanel({
    super.key,
    required this.channelId,
    required this.channelName,
  });

  final String channelId;
  final String channelName;

  @override
  ConsumerState<EpgPanel> createState() => _EpgPanelState();
}

class _EpgPanelState extends ConsumerState<EpgPanel> {
  late ScrollController _scrollController;
  final _now = DateTime.now();
  late DateTime _selectedDate = _dateOnly(_now);

  Channel? _channel;
  Source? _source;
  bool _loadingChannel = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Scroll to current programme after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    _loadChannelInfo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadChannelInfo() async {
    final db = ref.read(appDatabaseProvider);
    final channel = await db.getChannelById(widget.channelId);
    Source? source;
    if (channel != null && channel.hasCatchup) {
      source = await db.getSourceById(channel.sourceId);
    }
    if (!mounted) return;
    setState(() {
      _channel = channel;
      _source = source;
      _loadingChannel = false;
    });
  }

  bool get _isToday => _selectedDate.isAtSameMomentAs(_dateOnly(_now));

  bool get _canGoPrev {
    final channel = _channel;
    if (channel == null || !channel.hasCatchup) return false;
    final earliest =
        _dateOnly(_now.subtract(Duration(days: channel.catchupDays)));
    return _selectedDate.isAfter(earliest);
  }

  // Matches the EPG parser's own forward window — no point browsing further
  // ahead than the guide data could possibly extend to.
  bool get _canGoNext =>
      _selectedDate.isBefore(_dateOnly(_now.add(const Duration(days: 5))));

  void _shiftDay(int delta) {
    setState(() => _selectedDate = _selectedDate.add(Duration(days: delta)));
  }

  void _scrollToCurrent() {
    if (!_scrollController.hasClients) return;
    // Each programme card is approximately 180px wide with 8px gap.
    // This is a best-effort scroll; exact position depends on programme count.
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// A programme is catch-up-eligible once it has fully ended, the channel
  /// supports catch-up, and it falls within the provider's advertised
  /// retention window.
  bool _canCatchup(Programme p) {
    final channel = _channel;
    if (channel == null || !channel.hasCatchup || channel.streamId == null) {
      return false;
    }
    if (!p.end.isBefore(_now)) return false;
    final earliest = _now.subtract(Duration(days: channel.catchupDays));
    return p.start.isAfter(earliest);
  }

  Future<void> _playCatchup(Programme p) async {
    final channel = _channel;
    final source = _source;
    if (channel?.streamId == null ||
        source?.xtreamHost == null ||
        source?.xtreamUsername == null ||
        source?.xtreamPassword == null) {
      return;
    }

    final client = XtreamClient(
      host: source!.xtreamHost!,
      username: source.xtreamUsername!,
      password: source.xtreamPassword!,
      sourceId: source.id,
    );
    final url = client.buildCatchupUrl(channel!.streamId!, p.start, p.duration);
    client.dispose();

    final router = GoRouter.of(context);
    // pop() only dismisses this bottom sheet, leaving the still-playing live
    // PlayerScreen mounted underneath. push()-ing a second player screen on
    // top of it meant two screens fighting over the single shared Player —
    // the live screen's VideoController never detached, so mpv's native
    // callback thread fired into an object that got torn down mid-flight
    // (a real native crash, not just a logic bug). pushReplacement() instead
    // disposes the live screen first, matching the existing safe pattern
    // used for episode auto-advance in player_screen.dart.
    //
    // markTransitioning() tells the outgoing live PlayerScreen's dispose()
    // (which runs after this pushReplacement, from a screen instance this
    // code has no direct reference to) to skip its normal stop()/orientation
    // reset — otherwise it undoes the catch-up screen's just-started
    // playback and landscape lock a moment after they're set.
    ref.read(playbackServiceProvider).markTransitioning();
    router.pop();
    unawaited(router.pushReplacement('/player', extra: {
      'streamUrl': url,
      'title': p.title,
      'contentType': 'catchup',
      // Same key live playback uses for the channel id — keeps the EPG
      // guide button working in catch-up mode without a new field.
      'contentId': widget.channelId,
    }));
  }

  void _showCatchupUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Catch-up is not available for this programme.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final epg = ref.watch(epgServiceProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.channelName,
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _isToday ? 'Today' : _formatDate(_selectedDate),
                            style: theme.textTheme.bodySmall,
                          ),
                          if (!_loadingChannel &&
                              (_channel?.hasCatchup ?? false)) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.replay_circle_filled_outlined,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (!_loadingChannel && (_channel?.hasCatchup ?? false)) ...[
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous day',
                    onPressed: _canGoPrev ? () => _shiftDay(-1) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next day',
                    onPressed: _canGoNext ? () => _shiftDay(1) : null,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          FutureBuilder<List<Programme>>(
            future:
                epg.getProgrammesForChannel(widget.channelId, _selectedDate),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: LoadingView(),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    "Couldn't load the TV guide. Your channels still work — "
                    'guide info will retry automatically.',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }
              final programmes = snapshot.data!;
              if (programmes.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No guide information available for this day.',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }
              return SizedBox(
                height: 160,
                child: ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: programmes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final programme = programmes[i];
                    final catchupAvailable = _canCatchup(programme);
                    final isPast = programme.end.isBefore(_now);
                    // Only make past cards tappable at all when this channel
                    // supports catch-up — otherwise leave the existing silent
                    // no-op behavior alone instead of nagging with an error
                    // toast on every ordinary channel's past programmes.
                    final showsCatchupUi = _channel?.hasCatchup ?? false;
                    return _ProgrammeCard(
                      programme: programme,
                      now: _now,
                      catchupAvailable: catchupAvailable,
                      onTap: !isPast || !showsCatchupUi
                          ? null
                          : () => catchupAvailable
                              ? _playCatchup(programme)
                              : _showCatchupUnavailable(),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
  }
}

// ---------------------------------------------------------------------------
// Programme card
// ---------------------------------------------------------------------------

class _ProgrammeCard extends StatelessWidget {
  const _ProgrammeCard({
    required this.programme,
    required this.now,
    this.catchupAvailable = false,
    this.onTap,
  });

  final Programme programme;
  final DateTime now;
  final bool catchupAvailable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = programme.isLive;
    final isDone = now.isAfter(programme.end);
    final progress = programme.progressAt(now);

    final cardColor = isLive
        ? theme.colorScheme.primary.withValues(alpha: 0.15)
        : theme.colorScheme.surfaceContainerHighest;

    final borderColor = isLive ? theme.colorScheme.primary : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isLive ? 1.5 : 0),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time range
              Row(
                children: [
                  if (isLive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LIVE',
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      '${_formatTime(programme.start)} – ${_formatTime(programme.end)}',
                      style: theme.textTheme.bodySmall!.copyWith(
                        color: isDone
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (catchupAvailable)
                    Icon(Icons.replay_circle_filled_outlined,
                        size: 16, color: theme.colorScheme.primary),
                ],
              ),
              const SizedBox(height: 6),
              // Title
              Expanded(
                child: Text(
                  programme.title,
                  style: theme.textTheme.bodyMedium!.copyWith(
                    fontWeight: isLive ? FontWeight.w600 : FontWeight.normal,
                    color: isDone
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Progress bar for current programme
              if (isLive) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.12),
                    minHeight: 3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
