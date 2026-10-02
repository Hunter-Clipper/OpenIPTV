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

/// A tiny local stand-in for a provider: an Xtream panel that only accepts
/// [user]/[pass], and an M3U playlist at /list.m3u.
class _FakeProvider {
  late HttpServer server;
  String user = 'alice';
  String pass = 'new-secret';

  String get base => 'http://127.0.0.1:${server.port}';

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final q = req.uri.queryParameters;
      if (req.uri.path == '/list.m3u') {
        req.response.write('#EXTM3U\n'
            '#EXTINF:-1 group-title="News",Moved Channel\n'
            'http://example.com/live/9.m3u8\n');
      } else if (req.uri.path == '/player_api.php') {
        if (q['username'] != user || q['password'] != pass) {
          req.response.statusCode = 401;
        } else {
          req.response.write(jsonEncode(q['action'] == 'get_live_streams'
              ? [
                  {'stream_id': 7, 'name': 'Live Seven', 'category_id': '1'}
                ]
              : []));
        }
      } else {
        req.response.statusCode = 404;
      }
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
  final provider = _FakeProvider();

  setUpAll(provider.start);
  tearDownAll(() => provider.server.close(force: true));
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    manager = SourceManager(db: db, epgService: EpgService(db: db));
  });
  tearDown(() => db.close());

  Future<Source> saveXtream({String pass = 'old-secret'}) async {
    final s = Source(
      id: 'x1',
      nickname: 'Main',
      type: SourceType.xtream,
      xtreamHost: provider.base,
      xtreamUsername: 'alice',
      xtreamPassword: pass,
    );
    final withGuide = Source(
      id: s.id,
      nickname: s.nickname,
      type: s.type,
      xtreamHost: s.xtreamHost,
      xtreamUsername: s.xtreamUsername,
      xtreamPassword: s.xtreamPassword,
      epgUrl: SourceManager.automaticGuideUrl(s),
    );
    await db.upsertSource(withGuide);
    return withGuide;
  }

  test('renaming only saves the name, with no refresh', () async {
    final original = await saveXtream();
    final result = await manager.updateSource(original, nickname: 'Living Room');
    expect(result, isNull);
    final saved = await db.getSourceById('x1');
    expect(saved!.nickname, 'Living Room');
    expect(saved.xtreamPassword, 'old-secret');
  });

  test('a login the provider rejects is not saved', () async {
    final original = await saveXtream();
    await expectLater(
      manager.updateSource(original,
          nickname: 'Main', xtreamPassword: 'wrong'),
      throwsA(isA<SourceEditException>()
          .having((e) => e.code, 'code', 'xtream_login')),
    );
    expect((await db.getSourceById('x1'))!.xtreamPassword, 'old-secret');
  });

  test('a new password is checked, saved, and rebuilds links and guide',
      () async {
    final original = await saveXtream();
    final result = await manager.updateSource(original,
        nickname: 'Main', xtreamPassword: 'new-secret');
    expect(result!.playlistError, isNull);
    final saved = (await db.getSourceById('x1'))!;
    expect(saved.xtreamPassword, 'new-secret');
    // The automatic guide link follows the new login.
    expect(saved.epgUrl, contains('password=new-secret'));
    final channels = await db.getAllChannels();
    expect(channels.single.id, 'x1_ch_7');
    expect(channels.single.streamUrl, contains('/alice/new-secret/'));
  });

  test('a new server address moves every link and the guide to it',
      () async {
    final original = await saveXtream(pass: 'new-secret');
    final moved = _FakeProvider();
    await moved.start();
    addTearDown(() => moved.server.close(force: true));
    expect(moved.base, isNot(provider.base));

    await manager.updateSource(original,
        nickname: 'Main', xtreamHost: moved.base);

    final saved = (await db.getSourceById('x1'))!;
    expect(saved.xtreamHost, moved.base);
    expect(saved.epgUrl, startsWith('${moved.base}/xmltv.php'));
    final channels = await db.getAllChannels();
    expect(channels, isNotEmpty);
    for (final c in channels) {
      expect(c.streamUrl, startsWith(moved.base));
    }
  });

  test('an empty password keeps the current one', () async {
    final original = await saveXtream(pass: 'new-secret');
    await manager.updateSource(original,
        nickname: 'Main', xtreamHost: provider.base, xtreamPassword: '  ');
    expect((await db.getSourceById('x1'))!.xtreamPassword, 'new-secret');
  });

  test('a moved M3U playlist link is checked and reloaded', () async {
    const original = Source(
      id: 'm1',
      nickname: 'List',
      type: SourceType.m3u,
      m3uUrl: 'http://127.0.0.1:1/old.m3u',
    );
    await db.upsertSource(original);
    await expectLater(
      manager.updateSource(original,
          nickname: 'List', m3uUrl: 'http://127.0.0.1:1/still-dead.m3u'),
      throwsA(isA<SourceEditException>()
          .having((e) => e.code, 'code', 'm3u_unreachable')),
    );
    await manager.updateSource(original,
        nickname: 'List', m3uUrl: '${provider.base}/list.m3u');
    expect((await db.getSourceById('m1'))!.m3uUrl,
        '${provider.base}/list.m3u');
    expect((await db.getAllChannels()).map((c) => c.name), ['Moved Channel']);
  });
}
