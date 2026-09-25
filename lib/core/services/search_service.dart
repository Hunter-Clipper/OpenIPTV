import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/models/series.dart';

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

    // Name matches rank above channels found only via what's airing on them.
    final nameMatches = <Channel>[];
    final epgOnlyMatches = <Channel>[];
    for (final c in channels) {
      if (c.name.toLowerCase().contains(q)) {
        nameMatches.add(c);
      } else if (epgMatchedIds.contains(c.id)) {
        epgOnlyMatches.add(c);
      }
    }

    return SearchResults(
      channels: [...nameMatches, ...epgOnlyMatches],
      nowPlaying: {for (final p in currentProgrammes) p.channelId: p.title},
      movies: movies
          .where((m) => m.title.toLowerCase().contains(q))
          .toList(),
      series: series
          .where((s) => s.title.toLowerCase().contains(q))
          .toList(),
    );
  }
}
