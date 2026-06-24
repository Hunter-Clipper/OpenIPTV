import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/episode.dart';
import 'package:open_iptv/core/models/series.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _seriesDetailProvider =
    FutureProvider.family<Series?, String>((ref, id) async {
  final all = await ref.watch(appDatabaseProvider).getAllSeries();
  try {
    return all.firstWhere((s) => s.id == id);
  } catch (_) {
    return null;
  }
});

final _seriesEpisodesProvider =
    FutureProvider.family<List<Episode>, String>((ref, seriesId) {
  return ref.watch(appDatabaseProvider).getEpisodesForSeries(seriesId);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({super.key, required this.seriesId});

  final String seriesId;

  @override
  ConsumerState<SeriesDetailScreen> createState() =>
      _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  int _selectedSeason = 1;

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(_seriesDetailProvider(widget.seriesId));
    final episodesAsync =
        ref.watch(_seriesEpisodesProvider(widget.seriesId));
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final isFav =
        profile?.favoriteSeriesIds.contains(widget.seriesId) ?? false;

    return Scaffold(
      body: seriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorScaffold(onBack: () => context.pop()),
        data: (series) {
          if (series == null) {
            return _ErrorScaffold(onBack: () => context.pop());
          }
          return episodesAsync.when(
            loading: () => _SeriesBody(
              series: series,
              isFav: isFav,
              profileId: profile?.id,
              episodes: const [],
              selectedSeason: _selectedSeason,
              onSeasonChanged: (s) =>
                  setState(() => _selectedSeason = s),
              loading: true,
            ),
            error: (_, __) => _SeriesBody(
              series: series,
              isFav: isFav,
              profileId: profile?.id,
              episodes: const [],
              selectedSeason: _selectedSeason,
              onSeasonChanged: (s) =>
                  setState(() => _selectedSeason = s),
              loading: false,
            ),
            data: (episodes) {
              // If no episodes in DB yet, fetch them lazily from the API.
              if (episodes.isEmpty && series != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!mounted) return;
                  await ref
                      .read(sourceManagerProvider)
                      .fetchEpisodesForSeries(series.id, series.sourceId);
                  if (mounted) {
                    ref.invalidate(_seriesEpisodesProvider(widget.seriesId));
                  }
                });
              }

              // Auto-select first available season.
              final seasons = episodes
                  .map((e) => e.season)
                  .toSet()
                  .toList()
                ..sort();
              if (seasons.isNotEmpty &&
                  !seasons.contains(_selectedSeason)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _selectedSeason = seasons.first);
                  }
                });
              }
              return _SeriesBody(
                series: series,
                isFav: isFav,
                profileId: profile?.id,
                episodes: episodes,
                selectedSeason: _selectedSeason,
                onSeasonChanged: (s) =>
                    setState(() => _selectedSeason = s),
                loading: false,
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Series body
// ---------------------------------------------------------------------------

class _SeriesBody extends ConsumerWidget {
  const _SeriesBody({
    required this.series,
    required this.isFav,
    required this.profileId,
    required this.episodes,
    required this.selectedSeason,
    required this.onSeasonChanged,
    required this.loading,
  });

  final Series series;
  final bool isFav;
  final String? profileId;
  final List<Episode> episodes;
  final int selectedSeason;
  final void Function(int) onSeasonChanged;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final seasons =
        episodes.map((e) => e.season).toSet().toList()..sort();
    final seasonEpisodes = episodes
        .where((e) => e.season == selectedSeason)
        .toList()
      ..sort((a, b) => a.episode.compareTo(b.episode));

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 0,
          pinned: true,
          title: Text(series.title,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              icon: Icon(
                isFav ? Icons.star : Icons.star_border,
                color: isFav ? theme.colorScheme.primary : null,
              ),
              onPressed: profileId == null
                  ? null
                  : () => ref
                      .read(profileServiceProvider)
                      .toggleFavoriteSeries(profileId!, series.id),
            ),
          ],
        ),
        // Hero area: poster + metadata
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppTheme.cardRadius),
                  child: SizedBox(
                    width: 120,
                    height: 180,
                    child: _PosterImage(posterUrl: series.posterUrl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(series.title,
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      if (series.year != null)
                        _MetaRow(label: series.year!),
                      if (series.genre != null) ...[
                        const SizedBox(height: 4),
                        _MetaRow(label: series.genre!),
                      ],
                      const SizedBox(height: 12),
                      if (seasons.isNotEmpty) ...[
                        Text('Season',
                            style: theme.textTheme.bodySmall),
                        const SizedBox(height: 6),
                        _SeasonDropdown(
                          seasons: seasons,
                          selected: selectedSeason,
                          onChanged: onSeasonChanged,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Description
        if (series.description != null &&
            series.description!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(series.description!,
                  style: theme.textTheme.bodyMedium),
            ),
          ),
        // Episode list header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  seasons.isEmpty
                      ? 'Episodes'
                      : 'Season $selectedSeason',
                  style: theme.textTheme.titleMedium,
                ),
                if (seasons.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        context.push('/series/${series.id}/episodes'),
                    child: const Text('All Episodes'),
                  ),
              ],
            ),
          ),
        ),
        // Episodes
        if (loading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (seasonEpisodes.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                seasons.isEmpty
                    ? 'No episodes available yet.'
                    : 'No episodes for this season yet.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) =>
                  _EpisodeRow(episode: seasonEpisodes[i]),
              childCount: seasonEpisodes.length,
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Season dropdown
// ---------------------------------------------------------------------------

class _SeasonDropdown extends StatelessWidget {
  const _SeasonDropdown({
    required this.seasons,
    required this.selected,
    required this.onChanged,
  });

  final List<int> seasons;
  final int selected;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<int>(
        value: seasons.contains(selected) ? selected : seasons.first,
        items: seasons
            .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text('Season $s'),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        underline: const SizedBox.shrink(),
        isDense: true,
        dropdownColor: theme.colorScheme.surface,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Episode row
// ---------------------------------------------------------------------------

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({required this.episode});

  final Episode episode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: SizedBox(
        width: 56,
        child: Text(
          episode.episodeLabel,
          style: theme.textTheme.bodySmall!.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      title: Text(episode.title,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: episode.isInProgress
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: episode.watchProgress,
                  minHeight: 3,
                ),
              ),
            )
          : null,
      trailing:
          episode.isWatched ? const Icon(Icons.check_circle_outline) : null,
      onTap: () => context.push('/player', extra: {
        'streamUrl': episode.streamUrl,
        'title': '${episode.episodeLabel} – ${episode.title}',
        'contentId': episode.id,
        'contentType': 'episode',
        'resumePosition':
            episode.isInProgress ? episode.watchedDuration : null,
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.posterUrl});

  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    if (posterUrl == null || posterUrl!.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
            child: Icon(Icons.video_library_outlined, size: 40)),
      );
    }
    return CachedNetworkImage(
      imageUrl: posterUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      errorWidget: (_, __, ___) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
            child: Icon(Icons.video_library_outlined, size: 40)),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: Theme.of(context).textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            const Text("Couldn't load this series."),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: onBack, child: const Text('Go Back')),
          ],
        ),
      ),
    );
  }
}
