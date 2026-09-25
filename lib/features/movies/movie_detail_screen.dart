import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/utils/format.dart';
import 'package:open_iptv/shared/widgets/error_state_view.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';
import 'package:open_iptv/shared/widgets/poster_image.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _movieDetailProvider =
    StreamProvider.family<Movie?, String>((ref, id) {
  final profileId = ref.watch(activeProfileIdProvider);
  return ref.watch(appDatabaseProvider).watchMovieById(id, profileId: profileId);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MovieDetailScreen extends ConsumerWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  final String movieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movieAsync = ref.watch(_movieDetailProvider(movieId));
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final isFavourite =
        profile?.favoriteMovieIds.contains(movieId) ?? false;

    return Scaffold(
      body: movieAsync.when(
        loading: () => const LoadingView(),
        error: (_, __) => _buildError(context),
        data: (movie) {
          if (movie == null) return _buildError(context);
          return _MovieDetailBody(
            movie: movie,
            isFavourite: isFavourite,
            profileId: profile?.id,
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ErrorStateView(
        message: "Couldn't load this movie. Try again.",
        onRetry: () => context.pop(),
        retryLabel: 'Go Back',
      ),
    );
  }
}

class _MovieDetailBody extends ConsumerWidget {
  const _MovieDetailBody({
    required this.movie,
    required this.isFavourite,
    required this.profileId,
  });

  final Movie movie;
  final bool isFavourite;
  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final posterWidth = (screenWidth * 0.35).clamp(120.0, 200.0);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 0,
          pinned: true,
          title: Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            TvActivatable(
              onTap: profileId == null
                  ? null
                  : () => ref
                      .read(profileServiceProvider)
                      .toggleFavoriteMovie(profileId!, movie.id),
              builder: (onTap) => IconButton(
                icon: Icon(
                  isFavourite ? Icons.star : Icons.star_border,
                  color: isFavourite ? theme.colorScheme.primary : null,
                ),
                tooltip:
                    isFavourite ? 'Remove from Favorites' : 'Add to Favorites',
                onPressed: onTap,
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  child: SizedBox(
                    width: posterWidth,
                    height: posterWidth / AppTheme.posterAspectRatio,
                    child: PosterImage(
                        posterUrl: movie.posterUrl, iconSize: 40),
                  ),
                ),
                const SizedBox(width: 16),
                // Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(movie.title,
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      if (movie.year != null)
                        _MetaChip(label: movie.year!),
                      if (movie.genre != null) ...[
                        const SizedBox(height: 6),
                        _MetaChip(label: movie.genre!),
                      ],
                      if (movie.rating != null) ...[
                        const SizedBox(height: 6),
                        _MetaChip(label: '⭐ ${formatRating(movie.rating!)}'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Progress bar if in progress
        if (movie.isInProgress)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        movie.watchedDuration == null
                            ? '0:00'
                            : formatClock(movie.watchedDuration!),
                        style: theme.textTheme.bodySmall,
                      ),
                      Text(
                        movie.totalDuration == null
                            ? ''
                            : formatRuntime(movie.totalDuration!),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: movie.watchProgress,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        // Action buttons
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ActionButtons(movie: movie),
          ),
        ),
        // Description
        if (movie.description != null && movie.description!.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(movie.description!,
                      style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Action buttons
// ---------------------------------------------------------------------------

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.movie});

  final Movie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (movie.isInProgress) {
      final watched = movie.watchedDuration;
      final resumeLabel = watched == null ? '0:00' : formatClock(watched);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            autofocus: true,
            icon: const Icon(Icons.play_arrow),
            label: Text('Resume from $resumeLabel'),
            onPressed: () => context.push('/player', extra: {
              'streamUrl': movie.streamUrl,
              'title': movie.title,
              'contentId': movie.id,
              'contentType': 'movie',
              'resumePosition': movie.watchedDuration,
              'confirmResume': false,
            }),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.replay),
            label: const Text('Start Over'),
            onPressed: () => context.push('/player', extra: {
              'streamUrl': movie.streamUrl,
              'title': movie.title,
              'contentId': movie.id,
              'contentType': 'movie',
              'resumePosition': Duration.zero,
            }),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            icon: Icon(Icons.delete_outline,
                size: 16, color: Theme.of(context).colorScheme.error),
            label: const Text('Clear Progress'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onPressed: () async {
              final profileId =
                  ref.read(activeProfileProvider).valueOrNull?.id;
              if (profileId == null) return;
              await ref
                  .read(appDatabaseProvider)
                  .clearMovieProgress(profileId, movie.id);
            },
          ),
        ],
      );
    }

    return FilledButton.icon(
      autofocus: true,
      icon: const Icon(Icons.play_arrow),
      label: const Text('Play'),
      onPressed: () => context.push('/player', extra: {
        'streamUrl': movie.streamUrl,
        'title': movie.title,
        'contentId': movie.id,
        'contentType': 'movie',
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
