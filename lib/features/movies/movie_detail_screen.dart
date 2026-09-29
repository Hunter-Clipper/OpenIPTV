import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/content_details.dart';
import 'package:open_iptv/core/models/movie.dart';
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

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _movieDetailProvider =
    StreamProvider.family<Movie?, String>((ref, id) {
  final profileId = ref.watch(activeProfileIdProvider);
  return ref.watch(appDatabaseProvider).watchMovieById(id, profileId: profileId);
});

/// Backdrop, cast, runtime… fetched from the provider on first open and kept
/// for the session. Keyed by (movie id, source id).
final _movieExtrasProvider =
    FutureProvider.family<ContentDetails?, (String, String)>((ref, key) {
  return ref.read(sourceManagerProvider).fetchMovieDetails(key.$1, key.$2);
});

/// Titles sharing the movie's first genre — the "More Like This" row.
/// Keyed by (movie id, source id, genre).
final _moreLikeThisProvider = FutureProvider.autoDispose
    .family<List<Movie>, (String, String, String)>((ref, key) async {
  final (id, sourceId, genre) = key;
  final candidates = await ref.read(appDatabaseProvider).getMoviesInGenre(
      sourceId, genre,
      excludeId: id, profileId: ref.read(activeProfileIdProvider));
  final lower = genre.toLowerCase();
  // The SQL match is a substring one; keep exact genre-name matches only.
  return candidates
      .where((m) => splitGenres(m.genre).any((g) => g.toLowerCase() == lower))
      .take(20)
      .toList();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MovieDetailScreen extends ConsumerWidget {
  const MovieDetailScreen({super.key, required this.movieId, this.heroTag});

  final String movieId;
  // Tag of the poster that was tapped, so it flies into place.
  final String? heroTag;

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
            heroTag: heroTag,
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
    required this.heroTag,
    required this.isFavourite,
    required this.profileId,
  });

  final Movie movie;
  final String? heroTag;
  final bool isFavourite;
  final String? profileId;

  void _play(BuildContext context, {Duration? from, bool confirm = true}) {
    context.push('/player', extra: {
      'streamUrl': movie.streamUrl,
      'title': movie.title,
      'contentId': movie.id,
      'contentType': 'movie',
      if (from != null) 'resumePosition': from,
      if (!confirm) 'confirmResume': false,
    });
  }

  Future<void> _toggleFavourite(WidgetRef ref) async {
    await ref
        .read(profileServiceProvider)
        .toggleFavoriteMovie(profileId!, movie.id);
    // Favorites are cached on the profile; refresh so the star updates.
    ref.invalidate(activeProfileProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras =
        ref.watch(_movieExtrasProvider((movie.id, movie.sourceId))).valueOrNull;
    final genre = splitGenres(movie.genre).first;
    final more = movie.genre == null
        ? const <Movie>[]
        : _visible(
            ref,
            ref
                    .watch(_moreLikeThisProvider((movie.id, movie.sourceId, genre)))
                    .valueOrNull ??
                const []);

    final runtime = extras?.runtime ?? movie.totalDuration;
    final rating = extras?.rating ??
        (movie.rating == null ? null : formatRating(movie.rating!));
    final year = movie.year?.trim();
    final meta = [
      if (year != null && year.isNotEmpty) year,
      if (runtime != null && runtime > Duration.zero) formatRuntime(runtime),
      if (rating != null && rating != '0.0') '★ $rating',
      if (movie.genre != null) context.displayName(genre),
    ];

    final inProgress = movie.isInProgress;
    final watched = movie.watchedDuration;
    return CustomScrollView(
      slivers: [
        DetailHeader(
          title: context.displayName(movie.title),
          posterUrl: movie.posterUrl,
          backdropUrl: extras?.backdropUrl,
          heroTag: heroTag,
          meta: meta,
        ),
        SliverToBoxAdapter(
          child: DetailActions(
            primaryLabel: inProgress
                ? 'Resume from ${formatClock(watched ?? Duration.zero)}'
                : 'Play',
            progress: inProgress ? movie.watchProgress : null,
            onPrimary: () => inProgress
                ? _play(context, from: watched, confirm: false)
                : _play(context),
            secondary: [
              if (inProgress)
                RoundAction(
                  icon: Icons.replay_rounded,
                  label: 'Start Over',
                  onTap: () => _play(context, from: Duration.zero),
                ),
              RoundAction(
                icon: isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
                label: isFavourite ? 'Favorited' : 'Favorite',
                active: isFavourite,
                onTap: profileId == null ? null : () => _toggleFavourite(ref),
              ),
              if (inProgress)
                RoundAction(
                  icon: Icons.remove_done_rounded,
                  label: 'Clear Progress',
                  onTap: profileId == null
                      ? null
                      : () => ref
                          .read(appDatabaseProvider)
                          .clearMovieProgress(profileId!, movie.id),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: DetailSynopsis(
            text: extras?.plot ?? _nonEmpty(movie.description),
            cast: extras?.cast,
            director: extras?.director,
          ),
        ),
        if (more.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: MediaRail(
                title: 'More Like This',
                items: [
                  for (final m in more)
                    RailItem(
                      title: context.displayName(m.title),
                      imageUrl: m.posterUrl,
                      watched: m.isWatched,
                      progress: m.isInProgress ? m.watchProgress : null,
                      heroTag: posterHeroTag('more', m.id),
                      onTap: () => context.push('/movies/${m.id}',
                          extra: posterHeroTag('more', m.id)),
                    ),
                ],
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  /// Drops titles a kids profile mustn't see or that sit in a locked genre.
  List<Movie> _visible(WidgetRef ref, List<Movie> movies) {
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final unlocked = ref.watch(parentalSessionUnlockedProvider);
    final isKid = profile?.isKidsProfile ?? false;
    return movies
        .where((m) => !isKid || !isAdultGenre(m.genre))
        .where((m) => prefs == null || !isGenreLocked(m.genre, prefs, unlocked))
        .toList();
  }
}

String? _nonEmpty(String? s) => s == null || s.trim().isEmpty ? null : s;
