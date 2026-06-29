import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/widgets/app_logo.dart';
import 'package:open_iptv/ui/platform_helper.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _allMoviesProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(appDatabaseProvider).getAllMovies();
});

final _moviesInProgressProvider = StreamProvider<List<Movie>>((ref) {
  return ref.watch(appDatabaseProvider).watchMoviesInProgress();
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
  // null = genre grid; non-null = filtered movie grid
  String? _selectedGenre;

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

  List<Movie> _filteredMovies(List<Movie> all, String genre) {
    if (genre == 'All') return all;
    return all.where((m) {
      final g = m.genre ?? '';
      return g.toLowerCase().contains(genre.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(_allMoviesProvider);
    final inProgressAsync = ref.watch(_moviesInProgressProvider);
    final profileAsync = ref.watch(activeProfileProvider);
    final profile = profileAsync.valueOrNull;
    final columns = PlatformHelper.posterColumns(context);

    final sort = ref.watch(contentSortProvider);
    final viewMode = ref.watch(viewModeMoviesProvider);
    return Scaffold(
      appBar: AppBar(
        leading: _selectedGenre != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedGenre = null),
              )
            : const AppLogo(),
        title: Text(_selectedGenre != null
            ? (_selectedGenre == 'All' ? 'All Movies' : _selectedGenre!)
            : 'Movies'),
        actions: [
          if (_selectedGenre != null)
            IconButton(
              icon: Icon(
                  viewMode == 'grid' ? Icons.view_list : Icons.grid_view),
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
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: moviesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorView(onRetry: _refresh),
        data: (all) {
          final inProgress = inProgressAsync.valueOrNull ?? [];
          final favIdSet = (profile?.favoriteMovieIds ?? []).toSet();
          final favorites = all.where((m) => favIdSet.contains(m.id)).toList();

          if (_selectedGenre == null) {
            // Genre selection screen with Favorites + Continue Watching on top
            final hidden = profile?.hiddenCategories.toSet() ?? {};
            final genres = _buildGenres(all, hidden, sort);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  // Continue Watching
                  if (inProgress.isNotEmpty) ...[
                    _SectionHeader(title: 'Continue Watching'),
                    SliverToBoxAdapter(
                      child: _HorizontalPosterRow(
                        movies: inProgress,
                        profileId: profile?.id,
                        showProgress: true,
                        isContinueWatchingRow: true,
                      ),
                    ),
                  ],

                  // Favorites
                  if (favorites.isNotEmpty) ...[
                    _SectionHeader(title: 'Favorites'),
                    SliverToBoxAdapter(
                      child: _HorizontalPosterRow(
                        movies: favorites,
                        profileId: profile?.id,
                        showProgress: false,
                        isFavoritesRow: true,
                      ),
                    ),
                  ],

                  // Genre tiles
                  _SectionHeader(title: 'Browse by Genre'),
                  SliverToBoxAdapter(
                    child: _GenreTileList(
                      genres: genres.isEmpty ? ['All'] : genres,
                      movieCounts: {
                        if (genres.isEmpty) 'All': all.length,
                        for (final g in genres)
                          g: all
                              .where((m) => (m.genre ?? '').contains(g))
                              .length,
                      },
                      onTap: (g) => setState(() => _selectedGenre = g),
                      profileId: profile?.id,
                      onHideGenre: profile?.id == null
                          ? null
                          : (g) async {
                              HapticFeedback.mediumImpact();
                              final hide =
                                  await showModalBottomSheet<bool>(
                                context: context,
                                builder: (_) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(
                                            Icons.visibility_off_outlined),
                                        title:
                                            const Text('Hide Genre'),
                                        subtitle: Text(g,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                        onTap: () =>
                                            Navigator.of(context)
                                                .pop(true),
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
          }

          // Filtered movie grid or list
          final filtered = _filteredMovies(all, _selectedGenre!);
          if (sort == 'az') {
            filtered.sort((a, b) => a.title.compareTo(b.title));
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              key: ValueKey('${_selectedGenre}_${sort}_$viewMode'),
              slivers: [
                if (filtered.isEmpty)
                  const SliverFillRemaining(child: _EmptyView())
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
  });

  final List<String> genres;
  final Map<String, int> movieCounts;
  final void Function(String) onTap;
  final String? profileId;
  final void Function(String)? onHideGenre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: genres.map((g) {
        return ListTile(
          leading: Icon(
            g == 'All' ? Icons.movie_outlined : Icons.category_outlined,
            color: theme.colorScheme.primary,
          ),
          title: Text(g),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (movieCounts[g] ?? 0).toString(),
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
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
// Section header sliver
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
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
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Remove from Continue Watching'),
                onTap: () async {
                  Navigator.pop(context);
                  await ref
                      .read(appDatabaseProvider)
                      .clearMovieProgress(movie.id);
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      child: _PosterImage(posterUrl: movie.posterUrl),
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
        child: _PosterImage(posterUrl: movie.posterUrl,
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
            child: _PosterImage(posterUrl: movie.posterUrl),
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
          Positioned(
            top: 4,
            right: 4,
            child: _StarButton(
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

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.posterUrl, this.width, this.height});

  final String? posterUrl;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (posterUrl == null || posterUrl!.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.movie_outlined, size: 24),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: posterUrl!,
      fit: BoxFit.cover,
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      errorWidget: (_, __, ___) => Container(
        width: width,
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.movie_outlined, size: 24)),
      ),
    );
  }
}

class _StarButton extends StatelessWidget {
  const _StarButton({required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          isFavorite ? Icons.star : Icons.star_border,
          size: 16,
          color: isFavorite
              ? Theme.of(context).colorScheme.primary
              : Colors.white70,
        ),
      ),
    );
  }
}

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
          const Text("Couldn't load movies. Try again."),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No movies found.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
