import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

String stamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final u = t.toUtc();
  return '${u.year}${two(u.month)}${two(u.day)}${two(u.hour)}${two(u.minute)}${two(u.second)} +0000';
}

void main() {
  if (Platform.isLinux &&
      File('/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }

  late AppDatabase db;
  late HttpServer server;
  late String base;
  var body = '';

  String prog(String ch, DateTime start, int hours, String title) =>
      '<programme start="${stamp(start)}" stop="${stamp(start.add(Duration(hours: hours)))}" channel="$ch"><title>$title</title></programme>';

  Future<void> channel(String id, {String? tvg, int catchup = 0}) =>
      db.into(db.channels).insert(ChannelsCompanion.insert(
            id: id,
            sourceId: 'src',
            name: id,
            streamUrl: 'http://$id',
            tvgId: Value(tvg),
            catchupDays: Value(catchup),
          ));

  Future<List<String>> titles(String channelId) async => [
        for (final p in await (db.select(db.programmes)
              ..where((t) => t.channelId.equals(channelId))
              ..orderBy([(t) => OrderingTerm.asc(t.start)]))
            .get())
          p.title,
      ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      req.response.write(body);
      await req.response.close();
    });
    final now = DateTime.now();
    body = '<tv>'
        '<channel id="A"><display-name>Alpha</display-name></channel>'
        '<channel id="B"><display-name>Beta</display-name></channel>'
        '<channel id="Z"><display-name>Zulu</display-name></channel>'
        '${prog('A', now.subtract(const Duration(minutes: 10)), 1, 'a now')}'
        '${prog('A', now.add(const Duration(hours: 1)), 1, 'a later')}'
        // Beta only has something that ended hours ago (a stale guide).
        '${prog('B', now.subtract(const Duration(hours: 5)), 1, 'b long ago')}'
        '${prog('Z', now.add(const Duration(hours: 2)), 1, 'z later')}'
        '</tv>';
    await db.into(db.sources).insert(SourcesCompanion.insert(
        id: 'src', nickname: 'P', type: 'm3u', epgUrl: Value('$base/guide.xml')));
    await channel('src_a', tvg: 'A', catchup: 2);
    await channel('src_a2', tvg: 'A', catchup: 2); // same station listed twice
    await channel('src_b', tvg: 'B', catchup: 2);
    await channel('src_manual', tvg: 'A', catchup: 2); // user chose another guide
    await channel('src_linked'); // smart link to Z
    await db.setGuideLink(const GuideLinksCompanionArgs(
        channelId: 'src_manual', kind: 'manual', guideRef: 'ext:x', xmltvId: 'Q'));
    await db.setGuideLink(const GuideLinksCompanionArgs(
        channelId: 'src_linked', kind: 'auto', guideRef: 'src:src', xmltvId: 'Z'));
  });

  tearDown(() async {
    await server.close(force: true);
    await db.close();
  });

  Source source() => Source(
      id: 'src', nickname: 'P', type: SourceType.m3u, epgUrl: '$base/guide.xml');

  test('stores the guide\'s channel list and notes which entries are live',
      () async {
    await EpgService(db: db).refreshEpg(source());
    final list = {
      for (final c in await db.getGuideChannels())
        if (c.guideRef == 'src:src') c.xmltvId: c.hasProgrammes,
    };
    expect(list, {'A': true, 'B': false, 'Z': true}); // B holds only old programmes
    expect((await db.getGuideChannels()).firstWhere((c) => c.xmltvId == 'A').name,
        'Alpha');
  });

  test('every channel sharing a guide id gets the programmes', () async {
    await EpgService(db: db).refreshEpg(source());
    expect(await titles('src_a'), contains('a later'));
    expect(await titles('src_a2'), contains('a later'));
  });

  test('a channel the user gave a guide by hand is left to that choice',
      () async {
    await EpgService(db: db).refreshEpg(source());
    expect(await titles('src_manual'), isEmpty);
  });

  test('channels linked to this guide by name are filled from the same download',
      () async {
    await EpgService(db: db).refreshEpg(source());
    expect(await titles('src_linked'), ['z later']);
  });

  test('an empty answer changes nothing', () async {
    await EpgService(db: db).refreshEpg(source());
    final before = await titles('src_a');
    body = '<tv></tv>';
    await expectLater(EpgService(db: db).refreshEpg(source()), throwsA(anything));
    expect(await titles('src_a'), before);
    expect((await db.getGuideChannels()).where((c) => c.guideRef == 'src:src'),
        hasLength(3));
  });
}
