import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/content_details.dart';
import 'package:open_iptv/core/models/episode.dart';
import 'package:open_iptv/core/models/series.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/utils/format.dart';
import 'package:open_iptv/shared/widgets/detail_header.dart';
import 'package:open_iptv/shared/widgets/error_state_view.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';
import 'package:open_iptv/shared/widgets/media_rail.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _seriesDetailProvider =
    FutureProvider.family<Series?, String>((ref, id) {
  return ref.watch(appDatabaseProvider).getSeriesById(id);
});

final _seriesEpisodesProvider =
    StreamProvider.family<List<Episode>, String>((ref, seriesId) {
  final profileId = ref.watch(activeProfileIdProvider);
  return ref
      .watch(appDatabaseProvider)
      .watchEpisodesForSeries(seriesId, profileId: profileId);
});

/// Backdrop, cast, episode stills and synopses, fetched from the provider on
/// first open and kept for the session. Keyed by (series id, source id).
final _seriesExtrasProvider =
    FutureProvider.family<ContentDetails?, (String, String)>((ref, key) {
  return ref.read(sourceManagerProvider).fetchSeriesDetails(key.$1, key.$2);
});

/// Series sharing the first genre — "More Like This".
/// Keyed by (series id, source id, genre).
final _moreLikeThisProvider = FutureProvider.autoDispose
    .family<List<Series>, (String, String, String)>((ref, key) async {
  final (id, sourceId, genre) = key;
  final candidates = await ref
      .read(appDatabaseProvider)
      .getSeriesInGenre(sourceId, genre, excludeId: id);
  final lower = genre.toLowerCase();
  // The SQL match is a substring one; keep exact genre-name matches only.
  return candidates
      .where((s) => splitGenres(s.genre).any((g) => g.toLowerCase() == lower))
      .take(20)
      .toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SeriesDetailScreen extends ConsumerStatefulWidget {
  const SeriesDetailScreen({super.key, required this.seriesId, this.heroTag});

  final String seriesId;
  // Tag of the poster that was tapped, so it flies into place.
  final String? heroTag;

  @override
  ConsumerState<SeriesDetailScreen> createState() =>
      _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  int? _selectedSeason;
  bool _fetchRequested = false;
  bool _fetchDone = false;

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(_seriesDetailProvider(widget.seriesId));
    final episodesAsync = ref.watch(_seriesEpisodesProvider(widget.seriesId));
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final isFav =
        profile?.favoriteSeriesIds.contains(widget.seriesId) ?? false;

    return Scaffold(
      body: seriesAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => _ErrorScaffold(onBack: () => context.pop()),
        data: (series) {
          if (series == null) {
            return _ErrorScaffold(onBack: () => context.pop());
          }
          final episodes = episodesAsync.valueOrNull ?? const <Episode>[];
          // No episodes stored yet: fetch them from the provider once.
          if (episodesAsync.hasValue && episodes.isEmpty && !_fetchRequested) {
            _fetchRequested = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await ref
                  .read(sourceManagerProvider)
                  .fetchEpisodesForSeries(series.id, series.sourceId);
              if (!mounted) return;
              setState(() => _fetchDone = true);
              ref.invalidate(_seriesEpisodesProvider(widget.seriesId));
            });
          }
          final loading = episodes.isEmpty && !_fetchDone;
          return _SeriesBody(
            series: series,
            heroTag: widget.heroTag,
            isFav: isFav,
            profileId: profile?.id,
            episodes: episodes,
            loading: loading,
            selectedSeason: _selectedSeason,
            onSeasonChanged: (s) => setState(() => _selectedSeason = s),
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
    required this.heroTag,
    required this.isFav,
    required this.profileId,
    required this.episodes,
    required this.loading,
    required this.selectedSeason,
    required this.onSeasonChanged,
  });

  final Series series;
  final String? heroTag;
  final bool isFav;
  final String? profileId;
  final List<Episode> episodes;
  final bool loading;
  final int? selectedSeason;
  final void Function(int) onSeasonChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final extras = ref
        .watch(_seriesExtrasProvider((series.id, series.sourceId)))
        .valueOrNull;
    final genre = splitGenres(series.genre).first;
    final more = series.genre == null
        ? const <Series>[]
        : _visible(
            ref,
            ref
                    .watch(_moreLikeThisProvider(
                        (series.id, series.sourceId, genre)))
                    .valueOrNull ??
                const []);

    final seasons = episodes.map((e) => e.season).toSet().toList()..sort();
    final next = _nextPlayEpisode(episodes);
    // Default to the season of the episode you'd play next.
    final season = selectedSeason != null && seasons.contains(selectedSeason)
        ? selectedSeason!
        : (next?.season ?? (seasons.isEmpty ? 1 : seasons.first));
    final seasonEpisodes = episodes.where((e) => e.season == season).toList()
      ..sort((a, b) => a.episode.compareTo(b.episode));

    final year = _year(series.year ?? extras?.releaseDate);
    final meta = [
      if (year != null) year,
      if (seasons.length > 1) '${seasons.length} Seasons',
      if (extras?.rating != null) '★ ${extras!.rating}',
      if (series.genre != null) context.displayName(genre),
    ];

    return CustomScrollView(
      slivers: [
        DetailHeader(
          title: context.displayName(series.title),
          posterUrl: series.posterUrl,
          backdropUrl: extras?.backdropUrl,
          heroTag: heroTag,
          meta: meta,
          fallbackIcon: Icons.video_library_outlined,
        ),
        SliverToBoxAdapter(
          child: DetailActions(
            primaryLabel: next == null
                ? (loading ? 'Loading episodes…' : 'No episodes yet')
                : next.isInProgress
                    ? 'Resume ${_shortLabel(next)}'
                    : 'Play ${_shortLabel(next)}',
            progress: next?.isInProgress == true ? next!.watchProgress : null,
            onPrimary: next == null ? null : () => _playEpisode(context, next),
            secondary: [
              RoundAction(
                icon: isFav ? Icons.star_rounded : Icons.star_border_rounded,
                label: isFav ? 'Favorited' : 'Favorite',
                active: isFav,
                onTap: profileId == null
                    ? null
                    : () async {
                        await ref
                            .read(profileServiceProvider)
                            .toggleFavoriteSeries(profileId!, series.id);
                        // Favorites are cached on the profile; refresh so
                        // the star updates.
                        ref.invalidate(activeProfileProvider);
                      },
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: DetailSynopsis(
            text: extras?.plot ?? _nonEmpty(series.description),
            cast: extras?.cast,
            director: extras?.director,
          ),
        ),
        // Season picker
        SliverToBoxAdapter(
          child: seasons.length > 1
              ? _SeasonChips(
                  seasons: seasons,
                  selected: season,
                  onChanged: onSeasonChanged,
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                  child: Text('Episodes',
                      style: theme.textTheme.titleMedium!
                          .copyWith(fontWeight: FontWeight.w600, fontSize: 17)),
                ),
        ),
        if (loading && episodes.isEmpty)
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
              child: Text('No episodes available yet.',
                  style: theme.textTheme.bodySmall),
            ),
          )
        else
          SliverList.builder(
            itemCount: seasonEpisodes.length,
            itemBuilder: (context, i) {
              final ep = seasonEpisodes[i];
              return _EpisodeCard(
                episode: ep,
                details: extras?.episodes[_providerEpisodeId(ep)],
                fallbackImage: extras?.backdropUrl,
                seriesId: series.id,
              );
            },
          ),
        if (more.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: MediaRail(
                title: 'More Like This',
                fallbackIcon: Icons.video_library_outlined,
                items: [
                  for (final s in more)
                    RailItem(
                      title: context.displayName(s.title),
                      imageUrl: s.posterUrl,
                      heroTag: posterHeroTag('more', s.id),
                      onTap: () => context.push('/series/${s.id}',
                          extra: posterHeroTag('more', s.id)),
                    ),
                ],
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  /// Drops series a kids profile mustn't see or that sit in a locked genre.
  List<Series> _visible(WidgetRef ref, List<Series> list) {
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final unlocked = ref.watch(parentalSessionUnlockedProvider);
    final isKid = profile?.isKidsProfile ?? false;
    return list
        .where((s) => !isKid || !isAdultGenre(s.genre))
        .where((s) => prefs == null || !isGenreLocked(s.genre, prefs, unlocked))
        .toList();
  }

  // Local ids are "<source>_ep_<provider id>"; details are keyed by the latter.
  String _providerEpisodeId(Episode e) =>
      e.id.replaceFirst('${e.sourceId}_ep_', '');
}

// Returns the episode the primary button plays: first in-progress → first
// unwatched → the very first episode (everything watched: start again).
Episode? _nextPlayEpisode(List<Episode> episodes) {
  if (episodes.isEmpty) return null;
  final sorted = [...episodes]..sort((a, b) => a.season != b.season
      ? a.season.compareTo(b.season)
      : a.episode.compareTo(b.episode));
  return sorted.where((e) => e.isInProgress).firstOrNull ??
      sorted.where((e) => !e.isWatched).firstOrNull ??
      sorted.first;
}

String _shortLabel(Episode e) => 'S${e.season} E${e.episode}';

void _playEpisode(BuildContext context, Episode episode) {
  context.push('/player', extra: {
    'streamUrl': episode.streamUrl,
    'title': '${episode.episodeLabel} – ${episode.displayTitle}',
    'contentId': episode.id,
    'contentType': 'episode',
    // Needed for Up Next to find the following episode.
    'seriesId': episode.seriesId,
    'resumePosition': episode.isInProgress ? episode.watchedDuration : null,
  });
}

String? _year(String? date) {
  final m = RegExp(r'(19|20)\d\d').firstMatch(date ?? '');
  return m?.group(0);
}

String? _nonEmpty(String? s) => s == null || s.trim().isEmpty ? null : s;

// ---------------------------------------------------------------------------
// Season chips
// ---------------------------------------------------------------------------

class _SeasonChips extends StatelessWidget {
  const _SeasonChips({
    required this.seasons,
    required this.selected,
    required this.onChanged,
  });

  final List<int> seasons;
  final int selected;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        itemCount: seasons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = seasons[i];
          return TvActivatable(
            onTap: () => onChanged(s),
            builder: (onTap) => ChoiceChip(
              label: Text('Season $s'),
              selected: s == selected,
              showCheckmark: false,
              shape: const StadiumBorder(),
              onSelected: onTap == null ? null : (_) => onTap(),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Episode card
// ---------------------------------------------------------------------------

class _EpisodeCard extends ConsumerWidget {
  const _EpisodeCard({
    required this.episode,
    required this.details,
    required this.seriesId,
    this.fallbackImage,
  });

  final Episode episode;
  final EpisodeDetails? details;
  // The show's backdrop, dimmed, for episodes without a still.
  final String? fallbackImage;
  final String seriesId;

  void _showOptions(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(sheetContext).colorScheme.error),
              title: const Text('Clear Progress'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final profileId =
                    ref.read(activeProfileProvider).valueOrNull?.id;
                if (profileId == null) return;
                await ref
                    .read(appDatabaseProvider)
                    .clearEpisodeProgress(profileId, episode.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final thumbWidth = PlatformHelper.isTV(context) ? 200.0 : 148.0;
    final still = details?.stillUrl ?? episode.stillUrl;
    final runtime = details?.runtime ?? episode.totalDuration;
    final plot = details?.plot;
    final radius = BorderRadius.circular(10);
    void onTap() => _playEpisode(context, episode);

    return TvFocusable(
      wrapsGesture: false,
      onTap: onTap,
      ensureVisibleOnFocus: true,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress:
            episode.isInProgress ? () => _showOptions(context, ref) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: radius,
                child: SizedBox(
                  width: thumbWidth,
                  height: thumbWidth * 9 / 16,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (still != null)
                        _Still(url: still)
                      else
                        Opacity(
                          opacity: 0.45,
                          child: _Still(url: fallbackImage),
                        ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                      if (episode.isWatched)
                        const Positioned(
                          top: 5,
                          right: 5,
                          child: Icon(Icons.check_circle,
                              color: Colors.white, size: 16),
                        ),
                      if (episode.isInProgress)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: episode.watchProgress,
                            minHeight: 3,
                            backgroundColor: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${episode.episode}. ${episode.displayTitle}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (runtime != null && runtime > Duration.zero) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatRuntime(runtime),
                        style: theme.textTheme.bodySmall!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    if (plot != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        plot,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Still extends StatelessWidget {
  const _Still({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.surfaceContainerHighest;
    if (url == null || url!.isEmpty) return ColoredBox(color: fill);
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      memCacheWidth: 400,
      placeholder: (_, __) => ColoredBox(color: fill),
      errorWidget: (_, __, ___) => ColoredBox(color: fill),
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
      body: ErrorStateView(
        message: "Couldn't load this series. Try again.",
        onRetry: onBack,
        retryLabel: 'Go Back',
      ),
    );
  }
}
