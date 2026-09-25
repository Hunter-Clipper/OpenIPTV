import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/features/live_tv/catchup_launcher.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

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
  // Held in state (rather than built inline in build()) so unrelated
  // setState calls don't re-query the schedule; refreshed only on day change.
  late Future<List<Programme>> _programmesFuture;

  Channel? _channel;
  Source? _source;
  bool _loadingChannel = true;
  final _prevDayFocusNode = FocusNode();
  final _nextDayFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _programmesFuture = _loadProgrammes();
    _loadChannelInfo();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _prevDayFocusNode.dispose();
    _nextDayFocusNode.dispose();
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
    // Catch-up-capable channels show the day-switcher — give the D-pad
    // something to land on when the sheet opens. Non-catch-up channels have
    // no interactive controls in this panel at all, so there's nothing
    // sensible to focus.
    if (channel?.hasCatchup ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_canGoPrev) {
          _prevDayFocusNode.requestFocus();
        } else if (_canGoNext) {
          _nextDayFocusNode.requestFocus();
        }
      });
    }
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

  Future<List<Programme>> _loadProgrammes() async {
    final list = await ref
        .read(epgServiceProvider)
        .getProgrammesForChannel(widget.channelId, _selectedDate);
    // Once the list has laid out, bring what's on now into view (today) or
    // start from the beginning (any other day).
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent(list));
    return list;
  }

  void _shiftDay(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
      _programmesFuture = _loadProgrammes();
    });
  }

  void _scrollToCurrent(List<Programme> programmes) {
    if (!mounted || !_scrollController.hasClients) return;
    final i = _isToday ? programmes.indexWhere((p) => p.end.isAfter(_now)) : 0;
    final position = _scrollController.position;
    _scrollController.jumpTo(
      ((i < 0 ? 0 : i) * (_ProgrammeCard.width + _cardGap))
          .clamp(0.0, position.maxScrollExtent),
    );
  }

  static const _cardGap = 8.0;

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
    if (channel == null || source == null) return;
    await launchCatchup(
      context: context,
      ref: ref,
      channel: channel,
      source: source,
      programme: p,
      // Dismiss this bottom sheet first, leaving pushReplacement to replace
      // the still-playing live PlayerScreen underneath it.
      dismiss: () => Navigator.of(context).pop(),
    );
  }

  void _showCatchupUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Catch-up is not available for this programme.')),
    );
  }

  /// One chevron of the catch-up day switcher. When disabled it becomes a
  /// plain dimmed icon rather than a focusable target, so the D-pad never
  /// stops on a control that can't do anything.
  Widget _dayShiftButton({
    required IconData icon,
    required int days,
    required bool enabled,
    required FocusNode focusNode,
  }) {
    if (!enabled) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
      );
    }
    return TvFocusable(
      onTap: () => _shiftDay(days),
      focusNode: focusNode,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDaySwitcher = !_loadingChannel && (_channel?.hasCatchup ?? false);

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
                          if (showDaySwitcher) ...[
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
                if (showDaySwitcher) ...[
                  _dayShiftButton(
                    icon: Icons.chevron_left,
                    days: -1,
                    enabled: _canGoPrev,
                    focusNode: _prevDayFocusNode,
                  ),
                  _dayShiftButton(
                    icon: Icons.chevron_right,
                    days: 1,
                    enabled: _canGoNext,
                    focusNode: _nextDayFocusNode,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          FutureBuilder<List<Programme>>(
            future: _programmesFuture,
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
                  separatorBuilder: (_, __) => const SizedBox(width: _cardGap),
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

  // Wide enough for a 12-hour time range beside the LIVE badge.
  static const width = 200.0;

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

    final card = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: width,
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
                      '${_formatTime(context, programme.start)} – '
                      '${_formatTime(context, programme.end)}',
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
    if (onTap == null) return card;
    return TvFocusable(
      wrapsGesture: false,
      onTap: onTap!,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );
  }

  // Follows the device's 12/24-hour setting, matching the player overlay.
  String _formatTime(BuildContext context, DateTime dt) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(dt),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
}
