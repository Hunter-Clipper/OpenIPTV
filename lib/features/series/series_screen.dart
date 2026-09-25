import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/episode.dart';
import 'package:open_iptv/core/models/series.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/widgets/app_logo.dart';
import 'package:open_iptv/shared/widgets/browse_app_bar_actions.dart';
import 'package:open_iptv/shared/widgets/category_tile.dart';
import 'package:open_iptv/shared/widgets/empty_state_view.dart';
import 'package:open_iptv/shared/widgets/error_state_view.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';
import 'package:open_iptv/shared/widgets/parental_pin_dialog.dart';
import 'package:open_iptv/shared/widgets/poster_image.dart';
import 'package:open_iptv/shared/widgets/section_header.dart';
import 'package:open_iptv/shared/widgets/star_button.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _allSeriesProvider = StreamProvider<List<Series>>((ref) {
  final activeSourceId = ref.watch(activeSourceIdProvider);
  final db = ref.watch(appDatabaseProvider);
  if (activeSourceId != null) {
    return db.watchSeriesForSource(activeSourceId);
  }
  return db.watchAllSeries();
});

final _episodesInProgressProvider = StreamProvider<List<Episode>>((ref) {
  // Only the profile id matters here, so a favorite/watch-progress toggle
  // elsewhere (which invalidates activeProfileProvider) doesn't tear down
  // this stream.
  final profileId = ref.watch(activeProfileIdProvider);
  final db = ref.watch(appDatabaseProvider);
  if (profileId == null) return const Stream.empty();
  return db.watchEpisodesInProgress(profileId);
});

Future<void> _refreshSeries(WidgetRef ref) async {
  try {
    final sources = await ref.read(allSourcesProvider.future);
    for (final s in sources) {
      await ref.read(sourceManagerProvider).refreshSeries(s);
    }
  } finally {
    ref.invalidate(_allSeriesProvider);
    await ref.read(_allSeriesProvider.future);
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SeriesScreen extends ConsumerStatefulWidget {
  const SeriesScreen({super.key});

  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> {
  Future<void> _tapGenre(String g) async {
    if (await ensureCategoryUnlocked(context, ref, g) && mounted) {
      unawaited(context.push('/series/genre/${Uri.encodeComponent(g)}'));
    }
  }

  List<String> _buildGenres(
      List<Series> all, Set<String> hidden, String sort) {
    final seen = <String>{};
    final genres = <String>[];
    for (final s in all) {
      for (final g in splitGenres(s.genre)) {
        if (g.isNotEmpty && !hidden.contains(g) && seen.add(g)) genres.add(g);
      }
    }
    if (sort == 'az') genres.sort();
    return genres;
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(_allSeriesProvider);
    final profileAsync = ref.watch(activeProfileProvider);
    final profile = profileAsync.valueOrNull;

    final sort = ref.watch(contentSortProvider);
    final parentalPrefs = ref.watch(appPreferencesProvider).valueOrNull;
    final sessionUnlocked = ref.watch(parentalSessionUnlockedProvider);
    final inProgress =
        ref.watch(_episodesInProgressProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(
        leading: const AppLogo(),
        title: const Text('Series'),
        actions: const [
          SortToggleAction(),
          SettingsAction(),
        ],
      ),
      body: allAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => ErrorStateView(
          message: "Couldn't load series. Try again.",
          onRetry: () => _refreshSeries(ref),
        ),
        data: (all) {
          final isKid = profile?.isKidsProfile ?? false;
          final favIdSet = (profile?.favoriteSeriesIds ?? []).toSet();
          final favorites = all
              .where((s) => favIdSet.contains(s.id))
              .where((s) => !isKid || !isAdultGenre(s.genre))
              .toList();
          final seriesById = {for (final s in all) s.id: s};
          final visibleInProgress = inProgress.where((e) {
            if (!isKid) return true;
            final series = seriesById[e.seriesId];
            return series == null || !isAdultGenre(series.genre);
          }).toList();
          final hidden = profile?.hiddenCategories.toSet() ?? {};
          final genres = _buildGenres(all, hidden, sort)
              .where((g) => !isKid || !isAdultCategory(g))
              .toList();
          final lockedGenres = parentalPrefs == null
              ? const <String>{}
              : genres
                  .where((g) =>
                      isCategoryLocked(g, parentalPrefs, sessionUnlocked))
                  .toSet();
          final genreCounts = <String, int>{};
          for (final s in all) {
            for (final g in splitGenres(s.genre)) {
              if (g.isEmpty) continue;
              genreCounts[g] = (genreCounts[g] ?? 0) + 1;
            }
          }
          // Whichever section renders first gets its first item autofocused
          // so the D-pad can start navigating immediately once the page
          // loads, without an extra "warm-up" press.
          final firstSectionIsFavorites = favorites.isNotEmpty;
          final firstSectionIsContinueWatching =
              !firstSectionIsFavorites && visibleInProgress.isNotEmpty;
          final firstSectionIsGenres =
              !firstSectionIsFavorites && !firstSectionIsContinueWatching;
          return RefreshIndicator(
            onRefresh: () => _refreshSeries(ref),
            child: CustomScrollView(
              slivers: [
                if (favorites.isNotEmpty) ...[
                  const SectionHeaderSliver('Favorites'),
                  SliverToBoxAdapter(
                    child: _HorizontalPosterRow(
                      items: favorites,
                      profileId: profile?.id,
                      autofocusFirst: firstSectionIsFavorites,
                    ),
                  ),
                ],
                if (visibleInProgress.isNotEmpty) ...[
                  const SectionHeaderSliver('Continue Watching'),
                  SliverToBoxAdapter(
                    child: _EpisodeContinueWatchingRow(
                      episodes: visibleInProgress,
                      autofocusFirst: firstSectionIsContinueWatching,
                    ),
                  ),
                ],
                const SectionHeaderSliver('Browse by Genre'),
                SliverToBoxAdapter(
                  child: _GenreTileList(
                    genres: genres.isEmpty ? ['All'] : genres,
                    seriesCounts: {
                      if (genres.isEmpty) 'All': all.length,
                      for (final g in genres) g: genreCounts[g] ?? 0,
                    },
                    onTap: _tapGenre,
                    lockedGenres: lockedGenres,
                    profileId: profile?.id,
                    autofocusFirst: firstSectionIsGenres,
                    onHideGenre: profile?.id == null
                        ? null
                        : (g) async {
                            unawaited(HapticFeedback.mediumImpact());
                            final hide = await showModalBottomSheet<bool>(
                              context: context,
                              builder: (_) => SafeArea(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: const Icon(
                                          Icons.visibility_off_outlined),
                                      title: const Text('Hide Genre'),
                                      subtitle: Text(g,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                      onTap: () =>
                                          Navigator.of(context).pop(true),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            if (hide == true) {
                              await ref
                                  .read(profileServiceProvider)
                                  .hideCategory(profile!.id, g);
                              ref.invalidate(activeProfileProvider);
                            }
                          },
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Series genre screen (pushed as a route — back pops naturally)
// ---------------------------------------------------------------------------

class SeriesGenreScreen extends ConsumerStatefulWidget {
  const SeriesGenreScreen({super.key, required this.genre});
  final String genre;

  @override
  ConsumerState<SeriesGenreScreen> createState() => _SeriesGenreScreenState();
}

class _SeriesGenreScreenState extends ConsumerState<SeriesGenreScreen> {
  // Always a fresh list — the caller sorts it in place, and 'All' must not
  // mutate the provider's cached list.
  List<Series> _filtered(List<Series> all) {
    if (widget.genre == 'All') return List.of(all);
    final genre = widget.genre.toLowerCase();
    return all.where((s) {
      final g = s.genre ?? '';
      return g.toLowerCase().contains(genre);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(_allSeriesProvider);
    final profileAsync = ref.watch(activeProfileProvider);
    final profile = profileAsync.valueOrNull;
    final columns = PlatformHelper.posterColumns(context);
    final sort = ref.watch(contentSortProvider);
    final viewMode = ref.watch(viewModeSeriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.genre == 'All' ? 'All Series' : widget.genre),
        actions: [
          ViewModeToggleAction(
            provider: viewModeSeriesProvider,
            setMode: setViewModeSeries,
          ),
          const SortToggleAction(),
          const SettingsAction(),
        ],
      ),
      body: allAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => ErrorStateView(
          message: "Couldn't load series. Try again.",
          onRetry: () => _refreshSeries(ref),
        ),
        data: (all) {
          final filtered = _filtered(all);
          if (sort == 'az') {
            filtered.sort((a, b) => a.title.compareTo(b.title));
          }
          return RefreshIndicator(
            onRefresh: () => _refreshSeries(ref),
            child: CustomScrollView(
              key: ValueKey('${widget.genre}_${sort}_$viewMode'),
              slivers: [
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    child: EmptyStateView(
                      icon: Icons.video_library_outlined,
                      message: 'No series found.',
                    ),
                  )
                else if (viewMode == 'list')
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _SeriesListTile(
                        key: ValueKey(filtered[i].id),
                        series: filtered[i],
                        profileId: profile?.id,
                        autofocus: i == 0,
                      ),
                      childCount: filtered.length,
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _PosterCard(
                          key: ValueKey(filtered[i].id),
                          series: filtered[i],
                          profileId: profile?.id,
                          autofocus: i == 0,
                        ),
                        childCount: filtered.length,
                      ),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: AppTheme.posterAspectRatio,
                      ),
                    ),
                  ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Genre tile list
// ---------------------------------------------------------------------------

class _GenreTileList extends StatelessWidget {
  const _GenreTileList({
    required this.genres,
    required this.seriesCounts,
    required this.onTap,
    this.profileId,
    this.onHideGenre,
    this.lockedGenres = const {},
    this.autofocusFirst = false,
  });

  final List<String> genres;
  final Map<String, int> seriesCounts;
  final void Function(String) onTap;
  final String? profileId;
  final void Function(String)? onHideGenre;
  final Set<String> lockedGenres;
  final bool autofocusFirst;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < genres.length; i++)
          CategoryTile(
            label: genres[i],
            count: seriesCounts[genres[i]] ?? 0,
            icon: genres[i] == 'All'
                ? Icons.video_library_outlined
                : Icons.category_outlined,
            isLocked: lockedGenres.contains(genres[i]),
            onTap: () => onTap(genres[i]),
            onLongPress: genres[i] == 'All' || onHideGenre == null
                ? null
                : () => onHideGenre!(genres[i]),
            autofocus: autofocusFirst && i == 0,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal favorites row
// ---------------------------------------------------------------------------

class _HorizontalPosterRow extends ConsumerWidget {
  const _HorizontalPosterRow({
    required this.items,
    required this.profileId,
    this.autofocusFirst = false,
  });

  final List<Series> items;
  final String? profileId;
  final bool autofocusFirst;

  void _showRemoveSheet(BuildContext context, WidgetRef ref, Series s) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.star_border),
              title: const Text('Remove from Favorites'),
              onTap: () async {
                Navigator.pop(context);
                if (profileId != null) {
                  await ref
                      .read(profileServiceProvider)
                      .toggleFavoriteSeries(profileId!, s.id);
                  ref.invalidate(activeProfileProvider);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = items[i];
          return TvFocusable(
            onTap: () => context.push('/series/${s.id}'),
            onLongPress: profileId != null
                ? () => _showRemoveSheet(context, ref, s)
                : null,
            autofocus: autofocusFirst && i == 0,
            ensureVisibleOnFocus: true,
            child: SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppTheme.cardRadius),
                      child: PosterImage(posterUrl: s.posterUrl),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Series list tile (list view)
// ---------------------------------------------------------------------------

/// Long-press sheet shared by [_SeriesListTile] and [_PosterCard].
void _showSeriesOptions(
    BuildContext context, WidgetRef ref, Series series, String profileId) {
  HapticFeedback.mediumImpact();
  final isFav = ref
          .read(activeProfileProvider)
          .valueOrNull
          ?.favoriteSeriesIds
          .contains(series.id) ??
      false;
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(isFav ? Icons.star_border : Icons.star),
            title: Text(isFav ? 'Remove from Favorites' : 'Add to Favorites'),
            onTap: () async {
              Navigator.pop(context);
              await ref
                  .read(profileServiceProvider)
                  .toggleFavoriteSeries(profileId, series.id);
              ref.invalidate(activeProfileProvider);
            },
          ),
        ],
      ),
    ),
  );
}

class _SeriesListTile extends ConsumerWidget {
  const _SeriesListTile({
    super.key,
    required this.series,
    required this.profileId,
    this.autofocus = false,
  });

  final Series series;
  final String? profileId;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(activeProfileProvider.select(
        (a) => a.valueOrNull?.favoriteSeriesIds.contains(series.id) ?? false));
    void onTap() => context.push('/series/${series.id}');
    return TvFocusable(
      wrapsGesture: false,
      onTap: onTap,
      autofocus: autofocus,
      ensureVisibleOnFocus: true,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: PosterImage(
              posterUrl: series.posterUrl, width: 40, height: 56),
        ),
        title: Text(series.title,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: series.genre != null && series.genre!.isNotEmpty
            ? Text(series.genre!.split(',').first.trim(),
                maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        // A tappable IconButton, not a static status Icon — favoriting stays
        // consistent with Live TV's directly-tappable channel-row star.
        trailing: IconButton(
          icon: Icon(
            isFav ? Icons.star : Icons.star_border,
            color: isFav
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            size: 20,
          ),
          tooltip: isFav ? 'Remove from Favorites' : 'Add to Favorites',
          onPressed: profileId == null
              ? null
              : () async {
                  await ref
                      .read(profileServiceProvider)
                      .toggleFavoriteSeries(profileId!, series.id);
                  ref.invalidate(activeProfileProvider);
                },
        ),
        onTap: onTap,
        onLongPress:
            profileId == null ? null : () => _showSeriesOptions(context, ref, series, profileId!),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Poster card (grid)
// ---------------------------------------------------------------------------

class _PosterCard extends ConsumerWidget {
  const _PosterCard({
    super.key,
    required this.series,
    required this.profileId,
    this.autofocus = false,
  });

  final Series series;
  final String? profileId;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(activeProfileProvider.select(
        (a) => a.valueOrNull?.favoriteSeriesIds.contains(series.id) ?? false));

    return TvFocusable(
      onTap: () => context.push('/series/${series.id}'),
      onLongPress: profileId == null ? null : () => _showSeriesOptions(context, ref, series, profileId!),
      autofocus: autofocus,
      ensureVisibleOnFocus: true,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: PosterImage(posterUrl: series.posterUrl),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: StarButton(
              isFavorite: isFav,
              onTap: profileId == null
                  ? null
                  : () async {
                      await ref
                          .read(profileServiceProvider)
                          .toggleFavoriteSeries(profileId!, series.id);
                      ref.invalidate(activeProfileProvider);
                    },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Episode continue watching row
// ---------------------------------------------------------------------------

class _EpisodeContinueWatchingRow extends ConsumerWidget {
  const _EpisodeContinueWatchingRow({
    required this.episodes,
    this.autofocusFirst = false,
  });
  final List<Episode> episodes;
  final bool autofocusFirst;

  void _showRemoveSheet(BuildContext context, WidgetRef ref, Episode ep) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.remove_circle_outline,
                  color: Theme.of(context).colorScheme.error),
              title: const Text('Remove from Continue Watching'),
              onTap: () async {
                Navigator.pop(context);
                final profileId =
                    ref.read(activeProfileProvider).valueOrNull?.id;
                if (profileId == null) return;
                await ref
                    .read(appDatabaseProvider)
                    .clearEpisodeProgress(profileId, ep.id);
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
    // Build a series-id → posterUrl map so each episode card can show the
    // series poster rather than a still frame (which is often absent).
    final seriesPosterMap = <String, String?>{};
    ref.watch(_allSeriesProvider).valueOrNull?.forEach((s) {
      seriesPosterMap[s.id] = s.posterUrl;
    });

    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: episodes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final ep = episodes[i];
          final posterUrl = seriesPosterMap[ep.seriesId] ?? ep.stillUrl;
          return TvFocusable(
            onTap: () => context.push('/player', extra: {
              'streamUrl': ep.streamUrl,
              'title': '${ep.episodeLabel} – ${ep.title}',
              'contentId': ep.id,
              'contentType': 'episode',
              'resumePosition': ep.watchedDuration,
            }),
            onLongPress: () => _showRemoveSheet(context, ref, ep),
            autofocus: autofocusFirst && i == 0,
            ensureVisibleOnFocus: true,
            child: SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppTheme.cardRadius),
                          child: posterUrl != null && posterUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: posterUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholder: (_, __) => Container(
                                    color: theme.colorScheme
                                        .surfaceContainerHighest,
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: theme.colorScheme
                                        .surfaceContainerHighest,
                                    child: const Icon(
                                        Icons.video_library_outlined),
                                  ),
                                )
                              : Container(
                                  color: theme.colorScheme
                                      .surfaceContainerHighest,
                                  child: const Icon(
                                      Icons.video_library_outlined),
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(AppTheme.cardRadius)),
                            child: LinearProgressIndicator(
                              value: ep.watchProgress,
                              minHeight: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ep.episodeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    ep.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

