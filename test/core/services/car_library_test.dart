import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/services/car_library.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

void main() {
  if (Platform.isLinux &&
      File('/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }

  late AppDatabase db;
  final now = DateTime(2026);

  Profile profile({
    bool kids = false,
    List<String> hidden = const [],
    List<String> favChannels = const [],
  }) =>
      Profile(
        id: 'p1',
        name: 'Test',
        avatarEmoji: '🙂',
        createdAt: now,
        updatedAt: now,
        isKidsProfile: kids,
        hiddenCategories: hidden,
        favoriteChannelIds: favChannels,
      );

  Future<CarLibrary> library(Profile p,
      {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final appPrefs = AppPreferences(await SharedPreferences.getInstance());
    return CarLibrary(
      db: db,
      loadPrefs: () async => appPrefs,
      loadProfile: () async => p,
    );
  }

  Channel ch(String id, String name, String group, {String source = 's1'}) =>
      Channel(
        id: id,
        sourceId: source,
        name: name,
        streamUrl: 'http://h/live/u/p/$id.ts',
        sortOrder: 0,
        groupTitle: group,
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    for (final id in ['s1', 's2']) {
      await db.upsertSource(
          Source(id: id, nickname: id, type: SourceType.m3u, m3uUrl: 'x'));
    }
    await db.upsertChannels([
      ch('news', 'News 24', 'News'),
      ch('kids', 'Toon TV', 'Kids'),
      ch('adult', 'Late Night', 'Adult'),
      ch('other', 'Other One', 'News', source: 's2'),
    ]);
    await db.upsertMovies([
      const Movie(
          id: 'm1',
          sourceId: 's1',
          title: '|EN| SPACE FILM',
          streamUrl: 'http://h/movie/u/p/1.mp4',
          genre: 'Sci-Fi'),
    ]);
  });
  tearDown(() => db.close());

  test('root has the three tabs', () async {
    final lib = await library(profile());
    final root = await lib.children('root');
    expect(root.map((i) => i.title), ['Live TV', 'Movies', 'Series']);
    expect(root.every((i) => i.playable == false), isTrue);
  });

  test('no profile yet: a single "get started" message', () async {
    SharedPreferences.setMockInitialValues({});
    final lib = CarLibrary(
      db: db,
      loadPrefs: () async =>
          AppPreferences(await SharedPreferences.getInstance()),
      loadProfile: () async => null,
    );
    final items = await lib.children('root');
    expect(items.single.title, contains('Open OpenIPTV on your phone'));
  });

  test('Kids profiles never see adult categories or channels', () async {
    final lib = await library(profile(kids: true));
    final cats = (await lib.children('live')).map((i) => i.title).toList();
    expect(cats, containsAll(['News', 'Kids']));
    expect(cats, isNot(contains('Adult')));
    expect(await lib.resolve('ch|adult'), isNull);
  });

  test('parental-locked and hidden categories are left out', () async {
    final lib = await library(
      profile(hidden: ['Kids']),
      prefs: {
        'parental_protection_enabled': true,
        'parental_locked_cats': ['News'],
      },
    );
    final cats = (await lib.children('live')).map((i) => i.title).toList();
    expect(cats, isNot(contains('News')));
    expect(cats, isNot(contains('Kids')));
    expect(await lib.resolve('ch|news'), isNull);
  });

  test('only the active playlist is browsed', () async {
    final lib =
        await library(profile(), prefs: {'active_source_id': 's1'});
    final news = await lib.children('live/cat|News');
    expect(news.map((i) => i.id), ['ch|news']);
  });

  test('favourites and clean names', () async {
    final lib = await library(profile(favChannels: ['news']));
    final fav = await lib.children('live/fav');
    expect(fav.single.title, 'News 24');
    final movies = await lib.children('mov/genre|Sci-Fi');
    expect(movies.single.title, 'Space Film');
  });

  test('a movie in progress resumes where it was left', () async {
    await db.updateMovieProgress('p1', 'm1', const Duration(minutes: 10),
        const Duration(minutes: 100));
    final lib = await library(profile());
    final p = await lib.resolve('mv|m1');
    expect(p!.resumeAt, const Duration(minutes: 10));
    expect(p.isLive, isFalse);
    final cw = await lib.children('mov/cw');
    expect(cw.single.id, 'mv|m1');
  });

  test('search finds channels and movies', () async {
    final lib = await library(profile());
    final hits = await lib.search('space');
    expect(hits.map((i) => i.id), ['mv|m1']);
    expect((await lib.search('news')).first.id, 'ch|news');
  });
}
