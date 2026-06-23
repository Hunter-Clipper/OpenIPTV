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

Programme _pr(String channelId, String title) {
  final now = DateTime.now();
  return Programme(
    channelId: channelId,
    start: now.subtract(const Duration(minutes: 10)),
    end: now.add(const Duration(minutes: 50)),
    title: title,
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
    _ch('6', 'FX'),
  ];

  final movies = [
    _mv('m1', 'Interstellar'),
    _mv('m2', 'Inception'),
    _mv('m3', 'The Dark Knight'),
    _mv('m4', 'Mad Max: Fury Road'),
    _mv('m5', 'Avatar'),
  ];

  final series = [
    _sr('s1', 'Breaking Bad'),
    _sr('s2', 'Better Call Saul'),
    _sr('s3', 'The Office'),
  ];

  // FX is currently airing Avatar — EPG match test
  final currentProgrammes = [
    _pr('6', 'Avatar'),
    _pr('1', 'EastEnders'),
  ];

  group('SearchService.search', () {
    test('returns empty for query shorter than 2 chars', () {
      final result = service.search(
        query: 'b',
        channels: channels,
        currentProgrammes: [],
        movies: movies,
        series: series,
      );
      expect(result.isEmpty, isTrue);
    });

    test('returns empty for blank query', () {
      final result = service.search(
        query: '  ',
        channels: channels,
        currentProgrammes: [],
        movies: movies,
        series: series,
      );
      expect(result.isEmpty, isTrue);
    });

    test('matches channels by name (case-insensitive)', () {
      final result = service.search(
        query: 'BBC',
        channels: channels,
        currentProgrammes: [],
        movies: movies,
        series: series,
      );
      expect(result.channels.length, 3);
      expect(result.channels.map((c) => c.name),
          containsAll(['BBC One', 'BBC Two', 'BBC News']));
    });

    test('matches channel via current EPG programme title', () {
      // FX is showing Avatar — searching "avatar" should return FX channel
      final result = service.search(
        query: 'avatar',
        channels: channels,
        currentProgrammes: currentProgrammes,
        movies: movies,
        series: series,
      );
      expect(result.channels.any((c) => c.name == 'FX'), isTrue);
    });

    test('EPG match does not return duplicate when name also matches', () {
      // BBC One is named "BBC One" and its EPG has "EastEnders" — searching
      // "bbc" matches by name; no duplicate should appear.
      final result = service.search(
        query: 'bbc',
        channels: channels,
        currentProgrammes: currentProgrammes,
        movies: movies,
        series: series,
      );
      final bbcChannels =
          result.channels.where((c) => c.name.startsWith('BBC')).toList();
      expect(bbcChannels.length, 3);
    });

    test('searches movie titles', () {
      final result = service.search(
        query: 'inter',
        channels: channels,
        currentProgrammes: [],
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
        currentProgrammes: [],
        movies: movies,
        series: series,
      );
      expect(result.series.length, 1);
      expect(result.series.first.title, 'Breaking Bad');
    });

    test('no results for non-matching query', () {
      final result = service.search(
        query: 'xyz_no_match_12345',
        channels: channels,
        currentProgrammes: [],
        movies: movies,
        series: series,
      );
      expect(result.channels, isEmpty);
      expect(result.movies, isEmpty);
      expect(result.series, isEmpty);
      expect(result.isEmpty, isTrue);
    });

    test('strict contains — does not match non-substring patterns', () {
      // 'skys' is not a substring of 'Sky Sports 1'
      final result = service.search(
        query: 'skys',
        channels: channels,
        currentProgrammes: [],
        movies: movies,
        series: series,
      );
      expect(result.channels.any((c) => c.name == 'Sky Sports 1'), isFalse);
    });

    test('avatar returns both movie and EPG-matched channel', () {
      final result = service.search(
        query: 'avatar',
        channels: channels,
        currentProgrammes: currentProgrammes,
        movies: movies,
        series: series,
      );
      expect(result.movies.any((m) => m.title == 'Avatar'), isTrue);
      expect(result.channels.any((c) => c.name == 'FX'), isTrue);
    });
  });
}
