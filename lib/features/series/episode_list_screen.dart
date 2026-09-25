import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/episode.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/shared/utils/format.dart';
import 'package:open_iptv/shared/widgets/empty_state_view.dart';
import 'package:open_iptv/shared/widgets/error_state_view.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _episodeListProvider =
    StreamProvider.family<List<Episode>, String>((ref, seriesId) {
  final profileId = ref.watch(activeProfileIdProvider);
  return ref
      .watch(appDatabaseProvider)
      .watchEpisodesForSeries(seriesId, profileId: profileId);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class EpisodeListScreen extends ConsumerWidget {
  const EpisodeListScreen({super.key, required this.seriesId});

  final String seriesId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episodesAsync = ref.watch(_episodeListProvider(seriesId));

    return Scaffold(
      appBar: AppBar(title: const Text('All Episodes')),
      body: episodesAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => ErrorStateView(
          message: "Couldn't load episodes. Try again.",
          onRetry: () => ref.invalidate(_episodeListProvider(seriesId)),
        ),
        data: (episodes) {
          if (episodes.isEmpty) {
            return const EmptyStateView(
              icon: Icons.video_library_outlined,
              message: 'No episodes available yet.',
            );
          }

          // Group by season.
          final seasons = <int, List<Episode>>{};
          for (final ep in episodes) {
            seasons.putIfAbsent(ep.season, () => []).add(ep);
          }
          final sortedSeasons = seasons.keys.toList()..sort();
          for (final key in sortedSeasons) {
            seasons[key]!.sort((a, b) => a.episode.compareTo(b.episode));
          }

          return ListView.builder(
            itemCount: sortedSeasons.length,
            itemBuilder: (context, si) {
              final season = sortedSeasons[si];
              final eps = seasons[season]!;
              return _SeasonSection(
                season: season,
                episodes: eps,
                autofocusFirst: si == 0,
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Season section
// ---------------------------------------------------------------------------

class _SeasonSection extends StatelessWidget {
  const _SeasonSection({
    required this.season,
    required this.episodes,
    this.autofocusFirst = false,
  });

  final int season;
  final List<Episode> episodes;
  final bool autofocusFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Season $season',
            style: theme.textTheme.titleMedium,
          ),
        ),
        for (var i = 0; i < episodes.length; i++)
          _EpisodeRow(
            episode: episodes[i],
            autofocus: autofocusFirst && i == 0,
          ),
        const Divider(height: 1),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Episode row
// ---------------------------------------------------------------------------

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode, this.autofocus = false});

  final Episode episode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = episode.totalDuration;
    final durationText =
        total == null || total.inSeconds == 0 ? '' : formatRuntime(total);
    void onTap() => context.push('/player', extra: {
          'streamUrl': episode.streamUrl,
          'title': '${episode.episodeLabel} – ${episode.displayTitle}',
          'contentId': episode.id,
          'contentType': 'episode',
          'seriesId': episode.seriesId,
          'resumePosition':
              episode.isInProgress ? episode.watchedDuration : null,
        });

    return TvFocusable(
      wrapsGesture: false,
      autofocus: autofocus,
      ensureVisibleOnFocus: true,
      onTap: onTap,
      child: InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Episode label badge
            Container(
              width: 64,
              alignment: Alignment.topLeft,
              child: Text(
                episode.episodeLabel,
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Title + progress
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.displayTitle,
                    style: theme.textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (durationText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      durationText,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (episode.isInProgress) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: episode.watchProgress,
                              minHeight: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(episode.watchProgress * 100).round()}%',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Watched indicator
            if (episode.isWatched)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

