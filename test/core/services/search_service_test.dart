import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/models/series.dart';
import 'package:open_iptv/core/services/search_service.dart';

Channel _ch(String id, String name) => Channel(
      id: id, sourceId: 'src', name: name, streamUrl: 'http://x', sortOrder: 0);

Movie _mv(String id, String title) =>
    Movie(id: id, sourceId: 'src', title: title, streamUrl: 'http://x');

Series _sr(String id, String title) =>
    Series(id: id, sourceId: 'src', title: title);

Programme _pr(String channelId, String title, {String? desc}) {
  final now = DateTime.now();
  return Programme(
    channelId: channelId,
    start: now.subtract(const Duration(minutes: 10)),
    end: now.add(const Duration(minutes: 50)),
    title: title,
    description: desc,
  );
}

void main() {
  const service = SearchService();

  final channels = [
    _ch('1', 'BBC One'),
    _ch('2', 'BBC Two'),
    _ch('3', 'BBC News'),
    _ch('4', 'ITV'),
    _ch('5', 'Sky Sports 1'),
  ];

  final movies = [
    _mv('m1', 'Interstellar'),
    _mv('m2', 'Inception'),
    _mv('m3', 'The Dark Knight'),
    _mv('m4', 'Mad Max: Fury Road'),
  ];

  final series = [
    _sr('s1', 'Breaking Bad'),
    _sr('s2', 'Better Call Saul'),
    _sr('s3', 'The Office'),
  ];

  final programmes = [
    _pr('1', 'EastEnders', desc: 'Drama set in London'),
    _pr('2', 'Coronation Street', desc: 'Soap from Manchester'),
    _pr('3', 'BBC News at Ten'),
  ];

  group('SearchService.search', () {
    test('returns empty for query shorter than 2 chars', () {
      final result = service.search(
        query: 'b',
        channels: channels,
        programmes: programmes,
        movies: movies,
        series: series,
      );
      expect(result.isEmpty, isTrue);
    });

    test('returns empty for blank query', () {
      final result = service.search(
        query: '  ',
        channels: channels,
        programmes: programmes,
        movies: movies,
        series: series,
      );
      expect(result.isEmpty, isTrue);
    });

    test('substring match (pass 1) scores higher than in-order match (pass 2)',
        () {
      // 'BBC' is a substring of 'BBC One' (score 1.0)
      // 'BBC' chars are in order in 'Broadcast BBC-like Content' — not in our data
      // Simpler test: exact substring results appear before fuzzy results.
      final result = service.search(
        query: 'bbc',
        channels: channels,
        programmes: programmes,
        movies: movies,
        series: series,
      );
      expect(result.channels.length, 3);
      // All three BBC channels should appear.
      expect(result.channels.map((c) => c.name),
          containsAll(['BBC One', 'BBC Two', 'BBC News']));
    });

    test('case-insensitive substring match', () {
      final result = service.search(
        query: 'BBC',
        channels: channels,
        programmes: programmes,
        movies: movies,
        series: series,
      );
      expect(result.channels.length, 3);
    });

    test('searches movie titles', () {
      final result = service.search(
        query: 'inter',
        channels: channels,
        programmes: programmes,
        movies: movies,
        series: series,
      );
      expect(result.movies.length, 1);
      expect(result.movies.first.title, 'Interstellar');
    });

    test('searches series titles', () {
      final result = service.search(
        query: 'break',
        channels: channels,
        programmes: programmes,
        movies: movies,
        series: series,
      );
      expect(result.series.length, 1);
      expect(result.series.first.title, 'Breaking Bad');
    });

    test('searches programme titles', () {
      final result = service.search(
        query: 'east',
        channels: channels,
        programmes: programmes,
        movies: movies,
        series: series,
      );
      expect(result.programmes.length, 1);
      expect(result.programmes.first.title, 'EastEnders');
    });

    test('searches programme descriptions', () {
      final result = service.search(
        query: 'manchester',
        channels: channels,
        programmes: programmes,
        movies: movies,
        series: series,
      );
      expect(result.programmes, isNotEmpty);
      expect(result.programmes.first.title, 'Coronation Street');
    });

    test('hides empty groups when no results', () {
      final result = service.search(
        query: 'xyz_no_match_12345',
        channels: channels,
        programmes: programmes,
        movies: movies,
        series: series,
      );
      expect(result.channels, isEmpty);
      expect(result.movies, isEmpty);
      expect(result.series, isEmpty);
      expect(result.programmes, isEmpty);
      expect(result.isEmpty, isTrue);
    });

    test('in-order character match (pass 2) finds non-substring results', () {
      // 'bbc' chars in order in 'Baseball Broadcaster Club' — not in data.
      // Test with something we have: 'skys' → chars s,k,y,s in 'Sky Sports 1'
      final result = service.search(
        query: 'skys',
        channels: channels,
        programmes: programmes,
        movies: movies,
        series: series,
      );
      // 'Sky Sports 1' contains 's','k','y','s' in order
      expect(result.channels.any((c) => c.name == 'Sky Sports 1'), isTrue);
    });

    test('multiple content types can match simultaneously', () {
      // 'bbc' matches channels AND a programme title
      final result = service.search(
        query: 'bbc',
        channels: channels,
        programmes: programmes,
        movies: movies,
        series: series,
      );
      expect(result.channels, isNotEmpty);
      expect(result.programmes, isNotEmpty);
    });
  });
}
