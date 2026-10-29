import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/models/series.dart';
import 'package:open_iptv/core/storage/database.dart' show AppDatabase;

class SearchResults {
  const SearchResults({
    required this.channels,
    required this.movies,
    required this.series,
    this.nowPlaying = const {},
  });

  static const empty = SearchResults(
    channels: [],
    movies: [],
    series: [],
  );

  final List<Channel> channels;
  final List<Movie> movies;
  final List<Series> series;
  // Channel id → title of the matching programme airing now, so a channel
  // surfaced by its programme (not its name) can say why it's there.
  final Map<String, String> nowPlaying;

  bool get isEmpty =>
      channels.isEmpty && movies.isEmpty && series.isEmpty;
}

class SearchService {
  const SearchService(this.db);

  final AppDatabase db;

  static const minQueryLength = 2;

  /// Strict contains-match search, case-insensitive, run in the database.
  ///
  /// Channels match if their name contains [query] OR if a currently-airing
  /// EPG programme title contains [query] (TiviMate-style); name matches
  /// come first. [currentProgrammes] are the airing programmes that match
  /// [query] — their channelId surfaces the channel. [sourceId] limits the
  /// search to one playlist (null = all playlists).
  Future<SearchResults> search({
    required String query,
    required List<Programme> currentProgrammes,
    String? sourceId,
  }) async {
    final q = query.trim();
    if (q.length < minQueryLength) return SearchResults.empty;

    final found = await db.searchCatalog(
      q,
      sourceId: sourceId,
      airingChannelIds: {for (final p in currentProgrammes) p.channelId},
    );
    return SearchResults(
      channels: found.channels,
      nowPlaying: {for (final p in currentProgrammes) p.channelId: p.title},
      movies: found.movies,
      series: found.series,
    );
  }
}
