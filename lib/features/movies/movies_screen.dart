import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/movie.dart';
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

final _allMoviesProvider = StreamProvider<List<Movie>>((ref) {
  final activeSourceId = ref.watch(activeSourceIdProvider);
  final db = ref.watch(appDatabaseProvider);
  // Only the profile id matters for these queries. Watching the
  // whole activeProfileProvider meant toggling a favorite (which invalidates
  // activeProfileProvider to refresh favoriteMovieIds) tore down and
  // re-subscribed this entire stream, flashing the loading spinner even
  // though the movie list itself hadn't changed.
  final profileId = ref.watch(activeProfileIdProvider);
  if (activeSourceId != null) {
    return db.watchMoviesForSource(activeSourceId, profileId: profileId);
  }
  return db.watchAllMovies(profileId: profileId);
});

final _moviesInProgressProvider = StreamProvider<List<Movie>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  final db = ref.watch(appDatabaseProvider);
  if (profileId == null) return const Stream.empty();
  return db.watchMoviesInProgress(profileId);
});

Future<void> _refreshMovies(WidgetRef ref) async {
  try {
    final sources = await ref.read(allSourcesProvider.future);
    for (final s in sources) {
      await ref.read(sourceManagerProvider).refreshMovies(s);
    }
  } finally {
    ref.invalidate(_allMoviesProvider);
    await ref.read(_allMoviesProvider.future);
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MoviesScreen extends ConsumerStatefulWidget {
  const MoviesScreen({super.key});

  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen> {
  Future<void> _tapGenre(String g) async {
    if (await ensureCategoryUnlocked(context, ref, g) && mounted) {
      unawaited(context.push('/movies/genre/${Uri.encodeComponent(g)}'));
    }
  }

  List<String> _buildGenres(
      List<Movie> movies, Set<String> hidden, String sort) {
    final seen = <String>{};
    final genres = <String>[];
    for (final m in movies) {
      for (final g in splitGenres(m.genre)) {
        if (g.isNotEmpty && !hidden.contains(g) && seen.add(g)) genres.add(g);
      }
    }
    if (sort == 'az') genres.sort();
    return genres;
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(_allMoviesProvider);
    final inProgressAsync = ref.watch(_moviesInProgressProvider);
    final profileAsync = ref.watch(activeProfileProvider);
    final profile = profileAsync.valueOrNull;

    final sort = ref.watch(contentSortProvider);
    final parentalPrefs = ref.watch(appPreferencesProvider).valueOrNull;
    final sessionUnlocked = ref.watch(parentalSessionUnlockedProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppLogo(),
        title: const Text('Movies'),
        actions: const [
          SortToggleAction(),
          SettingsAction(),
        ],
      ),
      body: moviesAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => ErrorStateView(
          message: "Couldn't load movies. Try again.",
          onRetry: () => _refreshMovies(ref),
        ),
        data: (all) {
          final isKid = profile?.isKidsProfile ?? false;
          final inProgress = (inProgressAsync.valueOrNull ?? [])
              .where((m) => !isKid || !isAdultGenre(m.genre))
              .toList();
          final favIdSet = (profile?.favoriteMovieIds ?? []).toSet();
          final favorites = all
              .where((m) => favIdSet.contains(m.id))
              .where((m) => !isKid || !isAdultGenre(m.genre))
              .toList();
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
          for (final m in all) {
            for (final g in splitGenres(m.genre)) {
              if (g.isEmpty) continue;
              genreCounts[g] = (genreCounts[g] ?? 0) + 1;
            }
          }
          // Whichever section renders first gets its first item autofocused
          // so the D-pad can start navigating immediately once the page
          // loads, without an extra "warm-up" press.
          final firstSectionIsContinueWatching = inProgress.isNotEmpty;
          final firstSectionIsFavorites =
              !firstSectionIsContinueWatching && favorites.isNotEmpty;
          final firstSectionIsGenres =
              !firstSectionIsContinueWatching && !firstSectionIsFavorites;
          return RefreshIndicator(
            onRefresh: () => _refreshMovies(ref),
            child: CustomScrollView(
              slivers: [
                if (inProgress.isNotEmpty) ...[
                  const SectionHeaderSliver('Continue Watching'),
                  SliverToBoxAdapter(
                    child: _HorizontalPosterRow(
                      movies: inProgress,
                      profileId: profile?.id,
                      showProgress: true,
                      isContinueWatchingRow: true,
                      autofocusFirst: firstSectionIsContinueWatching,
                    ),
                  ),
                ],
                if (favorites.isNotEmpty) ...[
                  const SectionHeaderSliver('Favorites'),
                  SliverToBoxAdapter(
                    child: _HorizontalPosterRow(
                      movies: favorites,
                      profileId: profile?.id,
                      showProgress: false,
                      isFavoritesRow: true,
                      autofocusFirst: firstSectionIsFavorites,
                    ),
                  ),
                ],
                const SectionHeaderSliver('Browse by Genre'),
                SliverToBoxAdapter(
                  child: _GenreTileList(
                    genres: genres.isEmpty ? ['All'] : genres,
                    movieCounts: {
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
                              useRootNavigator: true,
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
// Movie genre screen (pushed as a route — back pops naturally)
// ---------------------------------------------------------------------------

class MovieGenreScreen extends ConsumerStatefulWidget {
  const MovieGenreScreen({super.key, required this.genre});
  final String genre;

  @override
  ConsumerState<MovieGenreScreen> createState() => _MovieGenreScreenState();
}

class _MovieGenreScreenState extends ConsumerState<MovieGenreScreen> {
  // Always a fresh list — the caller sorts it in place, and 'All' must not
  // mutate the provider's cached list.
  List<Movie> _filtered(List<Movie> all) {
    if (widget.genre == 'All') return List.of(all);
    final genre = widget.genre.toLowerCase();
    return all.where((m) {
      final g = m.genre ?? '';
      return g.toLowerCase().contains(genre);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(_allMoviesProvider);
    final profileAsync = ref.watch(activeProfileProvider);
    final profile = profileAsync.valueOrNull;
    final columns = PlatformHelper.posterColumns(context);
    final sort = ref.watch(contentSortProvider);
    final viewMode = ref.watch(viewModeMoviesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.genre == 'All' ? 'All Movies' : widget.genre),
        actions: [
          ViewModeToggleAction(
            provider: viewModeMoviesProvider,
            setMode: setViewModeMovies,
          ),
          const SortToggleAction(),
          const SettingsAction(),
        ],
      ),
      body: moviesAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => ErrorStateView(
          message: "Couldn't load movies. Try again.",
          onRetry: () => _refreshMovies(ref),
        ),
        data: (all) {
          final filtered = _filtered(all);
          if (sort == 'az') {
            filtered.sort((a, b) => a.title.compareTo(b.title));
          }
          return RefreshIndicator(
            onRefresh: () => _refreshMovies(ref),
            child: CustomScrollView(
              key: ValueKey('${widget.genre}_${sort}_$viewMode'),
              slivers: [
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    child: EmptyStateView(
                      icon: Icons.movie_outlined,
                      message: 'No movies found.',
                    ),
                  )
                else if (viewMode == 'list')
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _MovieListTile(
                        key: ValueKey(filtered[i].id),
                        movie: filtered[i],
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
                          movie: filtered[i],
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
    required this.movieCounts,
    required this.onTap,
    this.profileId,
    this.onHideGenre,
    this.lockedGenres = const {},
    this.autofocusFirst = false,
  });

  final List<String> genres;
  final Map<String, int> movieCounts;
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
            count: movieCounts[genres[i]] ?? 0,
            icon: genres[i] == 'All'
                ? Icons.movie_outlined
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
// Horizontal poster row (Continue Watching / Favorites)
// ---------------------------------------------------------------------------

class _HorizontalPosterRow extends ConsumerWidget {
  const _HorizontalPosterRow({
    required this.movies,
    required this.profileId,
    required this.showProgress,
    this.isFavoritesRow = false,
    this.isContinueWatchingRow = false,
    this.autofocusFirst = false,
  });

  final List<Movie> movies;
  final String? profileId;
  final bool showProgress;
  final bool isFavoritesRow;
  final bool isContinueWatchingRow;
  final bool autofocusFirst;

  void _showRowOptions(BuildContext context, WidgetRef ref, Movie movie) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isFavoritesRow)
              ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text('Remove from Favorites'),
                onTap: () async {
                  Navigator.pop(context);
                  if (profileId != null) {
                    await ref
                        .read(profileServiceProvider)
                        .toggleFavoriteMovie(profileId!, movie.id);
                    ref.invalidate(activeProfileProvider);
                  }
                },
              ),
            if (isContinueWatchingRow)
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
                      .clearMovieProgress(profileId, movie.id);
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
        itemCount: movies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final movie = movies[i];
          final hasLongPress = isFavoritesRow || isContinueWatchingRow;
          return TvFocusable(
            onTap: () => context.push('/movies/${movie.id}'),
            onLongPress: hasLongPress
                ? () => _showRowOptions(context, ref, movie)
                : null,
            autofocus: autofocusFirst && i == 0,
            ensureVisibleOnFocus: true,
            child: SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppTheme.cardRadius),
                          child: PosterImage(posterUrl: movie.posterUrl),
                        ),
                        if (movie.isWatched)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(1),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (showProgress && movie.isInProgress)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: movie.watchProgress,
                          minHeight: 3,
                        ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    movie.title,
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
// Movie list tile (list view)
// ---------------------------------------------------------------------------

/// Long-press sheet shared by [_MovieListTile] and [_PosterCard].
void _showMovieOptions(
    BuildContext context, WidgetRef ref, Movie movie, String profileId) {
  HapticFeedback.mediumImpact();
  final isFav = ref
          .read(activeProfileProvider)
          .valueOrNull
          ?.favoriteMovieIds
          .contains(movie.id) ??
      false;
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
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
                  .toggleFavoriteMovie(profileId, movie.id);
              ref.invalidate(activeProfileProvider);
            },
          ),
        ],
      ),
    ),
  );
}

class _MovieListTile extends ConsumerWidget {
  const _MovieListTile({
    super.key,
    required this.movie,
    required this.profileId,
    this.autofocus = false,
  });

  final Movie movie;
  final String? profileId;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(activeProfileProvider.select(
        (a) => a.valueOrNull?.favoriteMovieIds.contains(movie.id) ?? false));
    void onTap() => context.push('/movies/${movie.id}');
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
          child: PosterImage(posterUrl: movie.posterUrl,
              width: 40, height: 56),
        ),
        title: Text(movie.title,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: movie.genre != null && movie.genre!.isNotEmpty
            ? Text(movie.genre!.split(',').first.trim(),
                maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        // A tappable IconButton, not a static status Icon — Live TV's channel
        // rows already let you toggle favorite with a direct tap here; this
        // previously required a long-press to reach the same option, an
        // inconsistency between the two favoriting paths.
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
                      .toggleFavoriteMovie(profileId!, movie.id);
                  ref.invalidate(activeProfileProvider);
                },
        ),
        onTap: onTap,
        onLongPress:
            profileId == null ? null : () => _showMovieOptions(context, ref, movie, profileId!),
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
    required this.movie,
    required this.profileId,
    this.autofocus = false,
  });

  final Movie movie;
  final String? profileId;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TvFocusable(
      onTap: () => context.push('/movies/${movie.id}'),
      onLongPress: profileId == null ? null : () => _showMovieOptions(context, ref, movie, profileId!),
      autofocus: autofocus,
      ensureVisibleOnFocus: true,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: PosterImage(posterUrl: movie.posterUrl),
          ),
          if (movie.isInProgress)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppTheme.cardRadius)),
                child: LinearProgressIndicator(
                  value: movie.watchProgress,
                  minHeight: 3,
                ),
              ),
            ),
          if (movie.isWatched)
            Positioned(
              top: 5,
              left: 5,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Colors.white, size: 14),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: StarButton(
              isFavorite: ref.watch(activeProfileProvider.select((a) =>
                  a.valueOrNull?.favoriteMovieIds.contains(movie.id) ?? false)),
              onTap: profileId == null
                  ? null
                  : () async {
                      await ref
                          .read(profileServiceProvider)
                          .toggleFavoriteMovie(profileId!, movie.id);
                      ref.invalidate(activeProfileProvider);
                    },
            ),
          ),
        ],
      ),
    );
  }
}

