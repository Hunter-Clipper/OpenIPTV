import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/services/search_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:sqlite3/open.dart';

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
  // Linux hosts often ship only the versioned runtime library (no -dev
  // symlink), which package:sqlite3 won't find by default.
  if (Platform.isLinux &&
      File('/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }

  late AppDatabase db;
  late SearchService service;

  Future<void> source(String id) => db.into(db.sources).insert(
      SourcesCompanion.insert(id: id, nickname: id, type: 'm3u'));

  Future<void> channel(String id, String name, {String src = 'src'}) =>
      db.into(db.channels).insert(ChannelsCompanion.insert(
          id: id, sourceId: src, name: name, streamUrl: 'http://$id'));

  Future<void> movie(String id, String title, {String src = 'src'}) =>
      db.into(db.movies).insert(MoviesCompanion.insert(
          id: id, sourceId: src, title: title, streamUrl: 'http://$id'));

  Future<void> series(String id, String title) => db
      .into(db.seriesEntries)
      .insert(SeriesEntriesCompanion.insert(
          id: id, sourceId: 'src', title: title));

  // FX is currently airing Avatar — EPG match test
  final currentProgrammes = [
    _pr('6', 'Avatar'),
    _pr('1', 'EastEnders'),
  ];

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = SearchService(db);
    await source('src');
    for (final (id, name) in [
      ('1', 'BBC One'),
      ('2', 'BBC Two'),
      ('3', 'BBC News'),
      ('4', 'ITV'),
      ('5', 'Sky Sports 1'),
      ('6', 'FX'),
    ]) {
      await channel(id, name);
    }
    for (final (id, title) in [
      ('m1', 'Interstellar'),
      ('m2', 'Inception'),
      ('m3', 'The Dark Knight'),
      ('m4', 'Mad Max: Fury Road'),
      ('m5', 'Avatar'),
    ]) {
      await movie(id, title);
    }
    await series('s1', 'Breaking Bad');
    await series('s2', 'Better Call Saul');
    await series('s3', 'The Office');
  });
  tearDown(() => db.close());

  group('SearchService.search', () {
    test('returns empty for query shorter than 2 chars', () async {
      final result =
          await service.search(query: 'b', currentProgrammes: const []);
      expect(result.isEmpty, isTrue);
    });

    test('returns empty for blank query', () async {
      final result =
          await service.search(query: '  ', currentProgrammes: const []);
      expect(result.isEmpty, isTrue);
    });

    test('matches channels by name (case-insensitive)', () async {
      final result =
          await service.search(query: 'BBC', currentProgrammes: const []);
      expect(result.channels.map((c) => c.name),
          ['BBC One', 'BBC Two', 'BBC News']);
    });

    test('folds case beyond ASCII, like Dart toLowerCase', () async {
      await channel('7', 'ÉCOLE TV');
      await channel('8', 'ПЕРВЫЙ КАНАЛ');
      expect(
          (await service.search(query: 'école', currentProgrammes: const []))
              .channels
              .map((c) => c.name),
          ['ÉCOLE TV']);
      expect(
          (await service.search(query: 'первый', currentProgrammes: const []))
              .channels
              .map((c) => c.name),
          ['ПЕРВЫЙ КАНАЛ']);
    });

    test('treats % and _ in the query literally', () async {
      await channel('9', '100% Hits');
      expect(
          (await service.search(query: '0%', currentProgrammes: const []))
              .channels
              .map((c) => c.name),
          ['100% Hits']);
      expect(
          (await service.search(query: 'b_c', currentProgrammes: const []))
              .channels,
          isEmpty);
    });

    test('matches channel via current EPG programme title', () async {
      final result = await service.search(
          query: 'avatar', currentProgrammes: currentProgrammes);
      expect(result.channels.any((c) => c.name == 'FX'), isTrue);
    });

    test('EPG match does not return duplicate when name also matches',
        () async {
      // BBC One is named "BBC One" and its EPG has "EastEnders" — searching
      // "bbc" matches by name; no duplicate should appear.
      final result = await service.search(
          query: 'bbc', currentProgrammes: currentProgrammes);
      expect(result.channels.where((c) => c.name.startsWith('BBC')).length, 3);
    });

    test('searches movie titles', () async {
      final result =
          await service.search(query: 'inter', currentProgrammes: const []);
      expect(result.movies.map((m) => m.title), ['Interstellar']);
    });

    test('searches series titles', () async {
      final result =
          await service.search(query: 'break', currentProgrammes: const []);
      expect(result.series.map((s) => s.title), ['Breaking Bad']);
    });

    test('no results for non-matching query', () async {
      final result = await service.search(
          query: 'xyz_no_match_12345', currentProgrammes: const []);
      expect(result.isEmpty, isTrue);
    });

    test('strict contains — does not match non-substring patterns', () async {
      // 'skys' is not a substring of 'Sky Sports 1'
      final result =
          await service.search(query: 'skys', currentProgrammes: const []);
      expect(result.channels, isEmpty);
    });

    test('avatar returns both movie and EPG-matched channel', () async {
      final result = await service.search(
          query: 'avatar', currentProgrammes: currentProgrammes);
      expect(result.movies.any((m) => m.title == 'Avatar'), isTrue);
      expect(result.channels.any((c) => c.name == 'FX'), isTrue);
    });

    test('name matches rank above EPG-only matches, with now-playing',
        () async {
      await channel('av', 'Avatar Channel');
      final result = await service.search(
        query: 'avatar',
        currentProgrammes: [_pr('6', 'Avatar: The Way of Water')],
      );
      expect(result.channels.map((c) => c.name), ['Avatar Channel', 'FX']);
      expect(result.nowPlaying['6'], 'Avatar: The Way of Water');
    });

    test('follows the active playlist', () async {
      await source('other');
      await channel('o1', 'BBC Other', src: 'other');
      await movie('om', 'Inside Out', src: 'other');

      final all =
          await service.search(query: 'bbc', currentProgrammes: const []);
      expect(all.channels.length, 4);

      final other = await service.search(
          query: 'bbc', currentProgrammes: const [], sourceId: 'other');
      expect(other.channels.map((c) => c.name), ['BBC Other']);

      final mine = await service.search(
          query: 'in', currentProgrammes: const [], sourceId: 'src');
      expect(mine.movies.map((m) => m.title),
          isNot(contains('Inside Out')));
    });
  });
}
