import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/episode.dart';
import 'package:open_iptv/core/storage/database.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _episodeListProvider =
    FutureProvider.family<List<Episode>, String>((ref, seriesId) {
  return ref.watch(appDatabaseProvider).getEpisodesForSeries(seriesId);
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorView(
          onRetry: () => ref.invalidate(_episodeListProvider(seriesId)),
        ),
        data: (episodes) {
          if (episodes.isEmpty) {
            return Center(
              child: Text(
                'No episodes available yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
              return _SeasonSection(season: season, episodes: eps);
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
  });

  final int season;
  final List<Episode> episodes;

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
        ...episodes.map((ep) => _EpisodeRow(episode: ep)),
        const Divider(height: 1),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Episode row
// ---------------------------------------------------------------------------

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode});

  final Episode episode;

  String _formatDuration(Duration? d) {
    if (d == null || d.inSeconds == 0) return '';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final durationText = _formatDuration(episode.totalDuration);

    return InkWell(
      onTap: () => context.push('/player', extra: {
        'streamUrl': episode.streamUrl,
        'title': '${episode.episodeLabel} – ${episode.title}',
        'contentId': episode.id,
        'contentType': 'episode',
        'resumePosition':
            episode.isInProgress ? episode.watchedDuration : null,
      }),
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
                    episode.title,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          const Text('Couldn't load episodes. Try again.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}
