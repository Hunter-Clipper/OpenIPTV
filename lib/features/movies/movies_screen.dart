import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/ui/platform_helper.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _allMoviesProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(appDatabaseProvider).getAllMovies();
});

final _moviesInProgressProvider = FutureProvider<List<Movie>>((ref) {
  return ref.watch(appDatabaseProvider).getMoviesInProgress();
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
  String _selectedGenre = 'All';

  Future<void> _refresh() async {
    ref.invalidate(_allMoviesProvider);
    ref.invalidate(_moviesInProgressProvider);
    await ref.read(_allMoviesProvider.future);
  }

  List<String> _buildGenres(List<Movie> movies) {
    final genres = movies
        .map((m) => m.genre ?? 'Other')
        .expand((g) => g.split(',').map((s) => s.trim()))
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...genres];
  }

  List<Movie> _filteredMovies(List<Movie> all) {
    if (_selectedGenre == 'All') return all;
    return all.where((m) {
      final genre = m.genre ?? '';
      return genre.toLowerCase().contains(_selectedGenre.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final moviesAsync = ref.watch(_allMoviesProvider);
    final inProgressAsync = ref.watch(_moviesInProgressProvider);
    final profileAsync = ref.watch(activeProfileProvider);
    final profile = profileAsync.valueOrNull;
    final columns = PlatformHelper.posterColumns(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movies'),
        actions: [
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
          final genres = _buildGenres(all);
          final filtered = _filteredMovies(all);
          final inProgress = inProgressAsync.valueOrNull ?? [];
          final favIdSet = (profile?.favoriteMovieIds ?? []).toSet();
          final favourites =
              all.where((m) => favIdSet.contains(m.id)).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                // Genre chips
                SliverToBoxAdapter(
                  child: _GenreFilterRow(
                    genres: genres,
                    selected: _selectedGenre,
                    onSelected: (g) => setState(() => _selectedGenre = g),
                  ),
                ),

                // Continue Watching
                if (inProgress.isNotEmpty) ...[
                  _SectionHeader(title: 'Continue Watching'),
                  SliverToBoxAdapter(
                    child: _HorizontalPosterRow(
                      movies: inProgress,
                      profileId: profile?.id,
                      showProgress: true,
                    ),
                  ),
                ],

                // Favourites
                if (favourites.isNotEmpty) ...[
                  _SectionHeader(title: 'Favourites'),
                  SliverToBoxAdapter(
                    child: _HorizontalPosterRow(
                      movies: favourites,
                      profileId: profile?.id,
                      showProgress: false,
                    ),
                  ),
                ],

                // All movies grid
                _SectionHeader(title: 'All Movies'),
                filtered.isEmpty
                    ? const SliverFillRemaining(child: _EmptyView())
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _PosterCard(
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
// Genre filter row
// ---------------------------------------------------------------------------

class _GenreFilterRow extends StatelessWidget {
  const _GenreFilterRow({
    required this.genres,
    required this.selected,
    required this.onSelected,
  });

  final List<String> genres;
  final String selected;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: genres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ChoiceChip(
          label: Text(genres[i]),
          selected: genres[i] == selected,
          onSelected: (_) => onSelected(genres[i]),
        ),
      ),
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
// Horizontal poster row (Continue Watching / Favourites)
// ---------------------------------------------------------------------------

class _HorizontalPosterRow extends ConsumerWidget {
  const _HorizontalPosterRow({
    required this.movies,
    required this.profileId,
    required this.showProgress,
  });

  final List<Movie> movies;
  final String? profileId;
  final bool showProgress;

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
          return GestureDetector(
            onTap: () => context.push('/movies/${movie.id}'),
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
// Poster card (grid)
// ---------------------------------------------------------------------------

class _PosterCard extends ConsumerWidget {
  const _PosterCard({required this.movie, required this.profileId});

  final Movie movie;
  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/movies/${movie.id}'),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: _PosterImage(posterUrl: movie.posterUrl),
          ),
          // Progress bar at bottom
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
          // Star icon
          Positioned(
            top: 4,
            right: 4,
            child: _StarButton(
              isFavourite: ref.watch(activeProfileProvider.select((a) =>
                  a.valueOrNull?.favoriteMovieIds.contains(movie.id) ?? false)),
              onTap: profileId == null
                  ? null
                  : () => ref
                      .read(profileServiceProvider)
                      .toggleFavoriteMovie(profileId!, movie.id),
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
  const _PosterImage({required this.posterUrl});

  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    if (posterUrl == null || posterUrl!.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.movie_outlined, size: 40),
        ),
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
        child: const Center(child: Icon(Icons.movie_outlined, size: 40)),
      ),
    );
  }
}

class _StarButton extends StatelessWidget {
  const _StarButton({required this.isFavourite, required this.onTap});

  final bool isFavourite;
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
          isFavourite ? Icons.star : Icons.star_border,
          size: 16,
          color: isFavourite
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
