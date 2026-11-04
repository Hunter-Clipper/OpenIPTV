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
    this.programmes = const [],
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

  // Guide matches (title contains the query) with their channel: shows that
  // aired earlier, are on now, or are coming up. Earlier ones only where the
  // channel has catch-up.
  final List<ProgrammeMatch> programmes;

  bool get isEmpty =>
      channels.isEmpty &&
      movies.isEmpty &&
      series.isEmpty &&
      programmes.isEmpty;
}

class ProgrammeMatch {
  const ProgrammeMatch(this.programme, this.channel);
  final Programme programme;
  final Channel channel;
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
    List<Programme> guideMatches = const [],
    String? sourceId,
  }) async {
    final q = query.trim();
    if (q.length < minQueryLength) return SearchResults.empty;

    final found = await db.searchCatalog(
      q,
      sourceId: sourceId,
      airingChannelIds: {for (final p in currentProgrammes) p.channelId},
    );

    // What's on now for every channel shown (not just the ones found by
    // programme), so the cards say what's playing.
    final nowPlaying = {
      ...await db.currentTitlesFor(found.channels.take(150).map((c) => c.id)),
      for (final p in currentProgrammes) p.channelId: p.title,
    };

    // Guide matches, with their channels (current playlist only).
    final matchChannels = await db.getChannelsByIds(
        guideMatches.map((p) => p.channelId).toSet().take(300),
        sourceId: sourceId);
    final byId = {for (final c in matchChannels) c.id: c};
    final now = DateTime.now();
    final matches = <ProgrammeMatch>[];
    for (final p in guideMatches) {
      final c = byId[p.channelId];
      if (c == null) continue;
      final past = !p.end.isAfter(now);
      if (past) {
        // Only playable where the channel keeps catch-up, within its window.
        if (!c.hasCatchup || c.streamId == null) continue;
        if (p.start.isBefore(now.subtract(Duration(days: c.catchupDays)))) {
          continue;
        }
      }
      matches.add(ProgrammeMatch(p, c));
    }

    return SearchResults(
      channels: found.channels,
      nowPlaying: nowPlaying,
      programmes: matches,
      movies: found.movies,
      series: found.series,
    );
  }
}
