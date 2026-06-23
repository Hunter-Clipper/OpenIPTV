import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/models/series.dart';

class SearchResults {
  const SearchResults({
    required this.channels,
    required this.movies,
    required this.series,
  });

  static const empty = SearchResults(
    channels: [],
    movies: [],
    series: [],
  );

  final List<Channel> channels;
  final List<Movie> movies;
  final List<Series> series;

  bool get isEmpty =>
      channels.isEmpty && movies.isEmpty && series.isEmpty;
}

class SearchService {
  const SearchService();

  static const minQueryLength = 2;

  /// Strict contains-match search.
  ///
  /// Channels match if their name contains [query] OR if a currently-airing
  /// EPG programme title contains [query] (TiviMate-style).
  /// [currentProgrammes] is a list of programmes currently on air that match
  /// [query] — their channelId is used to surface the channel.
  SearchResults search({
    required String query,
    required List<Channel> channels,
    required List<Programme> currentProgrammes,
    required List<Movie> movies,
    required List<Series> series,
  }) {
    final q = query.trim().toLowerCase();
    if (q.length < minQueryLength) return SearchResults.empty;

    // Build set of channel IDs matched via EPG
    final epgMatchedIds = {for (final p in currentProgrammes) p.channelId};

    final matchedChannels = channels
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            epgMatchedIds.contains(c.id))
        .toList();

    return SearchResults(
      channels: matchedChannels,
      movies: movies
          .where((m) => m.title.toLowerCase().contains(q))
          .toList(),
      series: series
          .where((s) => s.title.toLowerCase().contains(q))
          .toList(),
    );
  }
}
