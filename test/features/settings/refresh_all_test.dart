import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/local_playlists.dart';
import 'package:open_iptv/features/settings/refresh_all.dart';
import 'package:sqlite3/open.dart';

SourceRefreshResult _result(String name,
        {Object? playlistError, Object? epgError}) =>
    SourceRefreshResult(
      sourceId: name,
      nickname: name,
      playlistError: playlistError,
      epgError: epgError,
    );

void main() {
  if (Platform.isLinux &&
      File('/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }

  group('refreshSummary', () {
    test('all good', () {
      final ok = [_result('A'), _result('B')];
      expect(refreshSummary(RefreshScope.everything, ok),
          'Everything is up to date.');
      expect(refreshSummary(RefreshScope.playlists, ok),
          'All playlists are up to date.');
      expect(refreshSummary(RefreshScope.guides, ok),
          'All TV guides are up to date.');
    });

    test('names what failed, in plain English', () {
      final results = [
        _result('Home'),
        _result('Main', epgError: 'http_404'),
        _result('Old', playlistError: 'x'),
        _result('Gone', playlistError: 'x', epgError: 'y'),
      ];
      expect(
        refreshSummary(RefreshScope.everything, results),
        "1 of 4 updated. Main's TV guide isn't available; "
        "Old's channels couldn't be refreshed; Gone couldn't be reached.",
      );
    });

    test('a single playlist skips the count', () {
      expect(
        refreshSummary(
            RefreshScope.guides, [_result('Main', epgError: 'http_404')]),
        "Main's TV guide isn't available.",
      );
    });
  });

  group('refreshSourceParts', () {
    late Directory tmp;
    late AppDatabase db;
    late SourceManager manager;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('otv_refresh_all');
      db = AppDatabase(NativeDatabase.memory());
      manager = SourceManager(
        db: db,
        epgService: EpgService(db: db),
        localPlaylists: LocalPlaylists(baseDir: () async => tmp),
      );
    });
    tearDown(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    Future<Source> add() => manager.addSource(
          nickname: 'File',
          type: SourceType.m3u,
          m3uFileContent: '#EXTM3U\n'
              '#EXTINF:-1 group-title="News",Channel One\n'
              'http://example.com/live/1.m3u8\n',
        );

    test('refreshes a playlist; no guide address is not a failure',
        () async {
      final source = await add();
      final result = await manager.refreshSourceParts(source);
      expect(result.succeeded, isTrue);
      expect((await db.getAllChannels()).map((c) => c.name), ['Channel One']);
    });

    test('reports a failed playlist instead of throwing', () async {
      final source = await add();
      for (final f in tmp.listSync(recursive: true).whereType<File>()) {
        f.deleteSync();
      }
      final result = await manager.refreshSourceParts(source);
      expect(result.playlistError, isA<LocalPlaylistException>());
      expect(result.epgError, isNull);
    });

    test('reports a guide that fails to load', () async {
      final source = await add();
      // Nothing listens on port 1: the guide fetch fails at once.
      final withGuide = source.copyWith(epgUrl: 'http://127.0.0.1:1/epg.xml');
      final result =
          await manager.refreshSourceParts(withGuide, playlist: false);
      expect(result.epgError, isNotNull);
      expect(result.playlistError, isNull);
    });

    test('guides only leaves the catalog alone', () async {
      final source = await add();
      for (final f in tmp.listSync(recursive: true).whereType<File>()) {
        f.deleteSync();
      }
      // The (now missing) playlist file isn't touched at all.
      final result =
          await manager.refreshSourceParts(source, playlist: false);
      expect(result.succeeded, isTrue);
    });
  });
}
