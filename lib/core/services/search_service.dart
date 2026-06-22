import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/models/series.dart';

class SearchResults {
  const SearchResults({
    required this.channels,
    required this.programmes,
    required this.movies,
    required this.series,
  });

  static const empty = SearchResults(
    channels: [],
    programmes: [],
    movies: [],
    series: [],
  );

  final List<Channel> channels;
  final List<Programme> programmes;
  final List<Movie> movies;
  final List<Series> series;

  bool get isEmpty =>
      channels.isEmpty &&
      programmes.isEmpty &&
      movies.isEmpty &&
      series.isEmpty;
}

class SearchService {
  const SearchService();

  static const minQueryLength = 2;

  SearchResults search({
    required String query,
    required List<Channel> channels,
    required List<Programme> programmes,
    required List<Movie> movies,
    required List<Series> series,
  }) {
    final q = query.trim();
    if (q.length < minQueryLength) return SearchResults.empty;

    return SearchResults(
      channels: _rank(q, channels, (c) => c.name),
      programmes: _rank(q, programmes, (p) => '${p.title} ${p.description ?? ''}'),
      movies: _rank(q, movies, (m) => m.title),
      series: _rank(q, series, (s) => s.title),
    );
  }

  // ---------------------------------------------------------------------------
  // Two-pass scorer — no library, zero dependencies.
  //
  // Pass 1 (score 1.0): query is a substring of the text (case-insensitive).
  // Pass 2 (score 0.5): every character of the query appears in order in text.
  // Anything else: excluded.
  //
  // Results within the same score band are returned in their original order
  // (stable sort), so provider order and A-Z are preserved.
  // ---------------------------------------------------------------------------

  List<T> _rank<T>(String query, List<T> items, String Function(T) text) {
    final q = query.toLowerCase();
    final scored = <({T item, double score})>[];

    for (final item in items) {
      final t = text(item).toLowerCase();
      final score = _score(q, t);
      if (score > 0) scored.add((item: item, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.item).toList();
  }

  double _score(String query, String text) {
    if (text.contains(query)) return 1.0;
    if (_charsInOrder(query, text)) return 0.5;
    return 0;
  }

  bool _charsInOrder(String query, String text) {
    var qi = 0;
    for (var i = 0; i < text.length && qi < query.length; i++) {
      if (text[i] == query[qi]) qi++;
    }
    return qi == query.length;
  }
}
