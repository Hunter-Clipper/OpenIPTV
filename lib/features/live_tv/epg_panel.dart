import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/services/epg_service.dart';

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

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Scroll to current programme after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.channelName, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  _formatDate(_now),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          FutureBuilder<List<Programme>>(
            future: epg.getProgrammesForChannel(widget.channelId, _now),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Couldn't load the TV guide. Your channels still work — '
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
                    'No guide information available for this channel.',
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
                    return _ProgrammeCard(
                      programme: programmes[i],
                      now: _now,
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
  const _ProgrammeCard({required this.programme, required this.now});

  final Programme programme;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLive = programme.isLive;
    final isDone = now.isAfter(programme.end);
    final progress = programme.progressAt(now);

    final cardColor = isLive
        ? theme.colorScheme.primary.withOpacity(0.15)
        : theme.colorScheme.surfaceContainerHighest;

    final borderColor = isLive
        ? theme.colorScheme.primary
        : Colors.transparent;

    return Container(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                    theme.colorScheme.onSurface.withOpacity(0.12),
                minHeight: 3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
