import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:sqlite3/open.dart';

/// An Xtream panel whose catalog grows by one title per refresh, and whose
/// movie list can be made to fail ([failMovies]) like a provider dropping
/// out halfway through a refresh.
class _FakePanel {
  late HttpServer server;
  bool failMovies = false;
  int version = 1;

  String get base => 'http://127.0.0.1:${server.port}';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final action = req.uri.queryParameters['action'];
      Object body = [];
      final ids = List.generate(version, (i) => i + 1);
      switch (action) {
        case 'get_live_streams':
          body = [
            for (final i in ids) {'stream_id': i, 'name': 'Channel $i'}
          ];
        case 'get_vod_streams':
          if (failMovies) {
            req.response.statusCode = 502;
            await req.response.close();
            return;
          }
          body = [
            for (final i in ids) {'stream_id': i, 'name': 'Movie $i'}
          ];
        case 'get_series':
          body = [
            for (final i in ids) {'series_id': i, 'name': 'Show $i'}
          ];
      }
      req.response.write(jsonEncode(body));
      await req.response.close();
    });
  }
}

void main() {
  if (Platform.isLinux &&
      File('/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }

  late AppDatabase db;
  late SourceManager manager;
  late Source source;
  final panel = _FakePanel();

  setUpAll(panel.start);
  tearDownAll(() => panel.server.close(force: true));
  setUp(() async {
    panel
      ..failMovies = false
      ..version = 1;
    db = AppDatabase(NativeDatabase.memory());
    manager = SourceManager(db: db, epgService: EpgService(db: db));
    source = Source(
      id: 'x1',
      nickname: 'Main',
      type: SourceType.xtream,
      xtreamHost: panel.base,
      xtreamUsername: 'alice',
      xtreamPassword: 'secret',
      epgUrl: '${panel.base}/xmltv.php',
    );
    await db.upsertSource(source);
    await manager.refreshPlaylist(source);
  });
  tearDown(() => db.close());

  Future<List<int>> counts() async => [
        (await db.getAllChannels()).length,
        (await db.getAllMovies()).length,
        (await db.getAllSeries()).length,
      ];

  test('a successful refresh replaces the catalog', () async {
    expect(await counts(), [1, 1, 1]);
    panel.version = 3;
    await manager.refreshPlaylist(source);
    expect(await counts(), [3, 3, 3]);
  });

  test('a provider failing halfway leaves the playlist as it was', () async {
    panel
      ..version = 3
      ..failMovies = true;
    await expectLater(manager.refreshPlaylist(source), throwsA(anything));
    // Channels downloaded fine before the failure, but nothing is replaced
    // until everything has arrived.
    expect(await counts(), [1, 1, 1]);
  });

  test('refresh everything reports the failure and keeps the catalog',
      () async {
    panel
      ..version = 3
      ..failMovies = true;
    final result = await manager.refreshSourceParts(source, guide: false);
    expect(result.playlistError, isNotNull);
    expect(await counts(), [1, 1, 1]);
  });

  test('pull-to-refresh of movies keeps them when the provider fails',
      () async {
    panel.failMovies = true;
    await expectLater(manager.refreshMovies(source), throwsA(anything));
    expect((await db.getAllMovies()).single.title, 'Movie 1');
  });
}
