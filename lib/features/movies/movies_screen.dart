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
import 'package:open_iptv/shared/widgets/category_tile.dart';
import 'package:open_iptv/shared/widgets/empty_state_view.dart';
import 'package:open_iptv/shared/widgets/error_state_view.dart';
import 'package:open_iptv/shared/widgets/parental_pin_dialog.dart';
import 'package:open_iptv/shared/widgets/poster_image.dart';
import 'package:open_iptv/shared/widgets/section_header.dart';
import 'package:open_iptv/shared/widgets/star_button.dart';
import 'package:open_iptv/ui/platform_helper.dart';

bool _movieGenreIsAdult(String? genre) =>
    (genre ?? 'Other').split(',').map((g) => g.trim()).any(isAdultCategory);

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _allMoviesProvider = StreamProvider<List<Movie>>((ref) {
  final activeSourceId = ref.watch(activeSourceIdProvider);
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileProvider).valueOrNull?.id;
  if (activeSourceId != null) {
    return db.watchMoviesForSource(activeSourceId, profileId: profileId);
  }
  return db.watchAllMovies(profileId: profileId);
});

final _moviesInProgressProvider = StreamProvider<List<Movie>>((ref) {
  final profileId = ref.watch(activeProfileProvider).valueOrNull?.id;
  final db = ref.watch(appDatabaseProvider);
  if (profileId == null) return const Stream.empty();
  return db.watchMoviesInProgress(profileId);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MoviesScreen extends ConsumerStatefulWidget {
  const MoviesScreen({super.key});

  @override
  ConsumerState<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends ConsumerState<MoviesScreen> {
  Future<void> _refresh() async {
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

  Future<void> _tapGenre(String g) async {
    final prefs = ref.read(appPreferencesProvider).valueOrNull;
    final sessionUnlocked = ref.read(parentalSessionUnlockedProvider);
    if (prefs != null && isCategoryLocked(g, prefs, sessionUnlocked)) {
      final pin = await showParentalPinEntry(
          context, 'Enter admin PIN to unlock "$g"');
      if (!mounted || pin == null) return;
      if (!await ref.read(profileServiceProvider).verifyAnyAdminPin(pin)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect PIN')));
        return;
      }
      ref.read(parentalSessionUnlockedProvider.notifier).state = {
        ...ref.read(parentalSessionUnlockedProvider),
        g,
      };
    }
    if (mounted) {
      unawaited(context.push('/movies/genre/${Uri.encodeComponent(g)}'));
    }
  }

  List<String> _buildGenres(
      List<Movie> movies, Set<String> hidden, String sort) {
    final seen = <String>{};
    final genres = <String>[];
    for (final m in movies) {
      for (final g in (m.genre ?? 'Other').split(',').map((s) => s.trim())) {
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
        actions: [
          IconButton(
            icon: Icon(sort == 'az' ? Icons.sort_by_alpha : Icons.sort),
            tooltip: sort == 'az' ? 'Sorted A–Z' : 'Provider order',
            onPressed: () async {
              final prefs = await ref.read(appPreferencesProvider.future);
              await setContentSort(
                  ref, sort == 'az' ? 'provider' : 'az', prefs);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: moviesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorStateView(
          message: "Couldn't load movies. Try again.",
          onRetry: _refresh,
        ),
        data: (all) {
          final isKid = profile?.isKidsProfile ?? false;
          final inProgress = (inProgressAsync.valueOrNull ?? [])
              .where((m) => !isKid || !_movieGenreIsAdult(m.genre))
              .toList();
          final favIdSet = (profile?.favoriteMovieIds ?? []).toSet();
          final favorites = all
              .where((m) => favIdSet.contains(m.id))
              .where((m) => !isKid || !_movieGenreIsAdult(m.genre))
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
            for (final g
                in (m.genre ?? 'Other').split(',').map((s) => s.trim())) {
              if (g.isEmpty) continue;
              genreCounts[g] = (genreCounts[g] ?? 0) + 1;
            }
          }
          return RefreshIndicator(
            onRefresh: _refresh,
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
// Movie genre screen (pushed as a route — back pops naturally)
// ---------------------------------------------------------------------------

class MovieGenreScreen extends ConsumerStatefulWidget {
  const MovieGenreScreen({super.key, required this.genre});
  final String genre;

  @override
  ConsumerState<MovieGenreScreen> createState() => _MovieGenreScreenState();
}

class _MovieGenreScreenState extends ConsumerState<MovieGenreScreen> {
  Future<void> _refresh() async {
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

  List<Movie> _filtered(List<Movie> all) {
    if (widget.genre == 'All') return all;
    return all.where((m) {
      final g = m.genre ?? '';
      return g.toLowerCase().contains(widget.genre.toLowerCase());
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
          IconButton(
            icon:
                Icon(viewMode == 'grid' ? Icons.view_list : Icons.grid_view),
            tooltip: viewMode == 'grid'
                ? 'Switch to list view'
                : 'Switch to grid view',
            onPressed: () async {
              final prefs = await ref.read(appPreferencesProvider.future);
              await setViewModeMovies(
                  ref, viewMode == 'grid' ? 'list' : 'grid', prefs);
            },
          ),
          IconButton(
            icon: Icon(sort == 'az' ? Icons.sort_by_alpha : Icons.sort),
            tooltip: sort == 'az' ? 'Sorted A–Z' : 'Provider order',
            onPressed: () async {
              final prefs = await ref.read(appPreferencesProvider.future);
              await setContentSort(
                  ref, sort == 'az' ? 'provider' : 'az', prefs);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: moviesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorStateView(
          message: "Couldn't load movies. Try again.",
          onRetry: _refresh,
        ),
        data: (all) {
          final filtered = _filtered(all);
          if (sort == 'az') {
            filtered.sort((a, b) => a.title.compareTo(b.title));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
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
  });

  final List<String> genres;
  final Map<String, int> movieCounts;
  final void Function(String) onTap;
  final String? profileId;
  final void Function(String)? onHideGenre;
  final Set<String> lockedGenres;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: genres.map((g) {
        final locked = lockedGenres.contains(g);
        return CategoryTile(
          label: g,
          count: movieCounts[g] ?? 0,
          icon: g == 'All' ? Icons.movie_outlined : Icons.category_outlined,
          isLocked: locked,
          onTap: () => onTap(g),
          onLongPress: g == 'All' || onHideGenre == null
              ? null
              : () => onHideGenre!(g),
        );
      }).toList(),
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
  });

  final List<Movie> movies;
  final String? profileId;
  final bool showProgress;
  final bool isFavoritesRow;
  final bool isContinueWatchingRow;

  void _showRowOptions(BuildContext context, WidgetRef ref, Movie movie) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
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
          return GestureDetector(
            onTap: () => context.push('/movies/${movie.id}'),
            onLongPress: hasLongPress
                ? () => _showRowOptions(context, ref, movie)
                : null,
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

class _MovieListTile extends ConsumerWidget {
  const _MovieListTile({super.key, required this.movie, required this.profileId});

  final Movie movie;
  final String? profileId;

  void _showOptions(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    final isFav = ref
            .read(activeProfileProvider)
            .valueOrNull
            ?.favoriteMovieIds
            .contains(movie.id) ??
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
                if (profileId != null) {
                  await ref
                      .read(profileServiceProvider)
                      .toggleFavoriteMovie(profileId!, movie.id);
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
    final isFav = ref.watch(activeProfileProvider.select(
        (a) => a.valueOrNull?.favoriteMovieIds.contains(movie.id) ?? false));
    return ListTile(
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
      trailing: Icon(
        isFav ? Icons.star : Icons.star_border,
        color: isFav
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        size: 20,
      ),
      onTap: () => context.push('/movies/${movie.id}'),
      onLongPress: profileId == null ? null : () => _showOptions(context, ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Poster card (grid)
// ---------------------------------------------------------------------------

class _PosterCard extends ConsumerWidget {
  const _PosterCard({super.key, required this.movie, required this.profileId});

  final Movie movie;
  final String? profileId;

  void _showOptions(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    final isFav = ref
            .read(activeProfileProvider)
            .valueOrNull
            ?.favoriteMovieIds
            .contains(movie.id) ??
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
                if (profileId != null) {
                  await ref
                      .read(profileServiceProvider)
                      .toggleFavoriteMovie(profileId!, movie.id);
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
    return GestureDetector(
      onTap: () => context.push('/movies/${movie.id}'),
      onLongPress: profileId == null ? null : () => _showOptions(context, ref),
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

