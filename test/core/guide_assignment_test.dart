import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/guide_assignment_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

String stamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final u = t.toUtc();
  return '${u.year}${two(u.month)}${two(u.day)}${two(u.hour)}${two(u.minute)}${two(u.second)} +0000';
}

String feed(Map<String, String> channels) {
  final now = DateTime.now();
  final b = StringBuffer('<?xml version="1.0"?><tv>');
  channels.forEach((id, name) {
    b.write('<channel id="$id">${name.isEmpty ? '' : '<display-name>$name</display-name>'}</channel>');
  });
  for (final id in channels.keys) {
    for (var i = 0; i < 4; i++) {
      final s = now.add(Duration(hours: i));
      b.write('<programme start="${stamp(s)}" stop="${stamp(s.add(const Duration(hours: 1)))}" channel="$id"><title>$id #$i</title></programme>');
    }
  }
  return (b..write('</tv>')).toString();
}

void main() {
  if (Platform.isLinux &&
      File('/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }

  late AppDatabase db;
  late HttpServer server;
  late Directory tmp;
  late GuideAssignmentService service;
  late String base;
  var providerHits = 0;

  Future<void> channel(String id, String name, {String? tvgId}) =>
      db.into(db.channels).insert(ChannelsCompanion.insert(
            id: id,
            sourceId: 'src',
            name: name,
            streamUrl: 'http://$id',
            tvgId: Value(tvgId),
          ));

  Future<int> programmesOf(String channelId) async => (await (db.select(db.programmes)
            ..where((t) => t.channelId.equals(channelId)))
          .get())
      .length;

  Future<GuideLinkRow?> link(String c) => db.getGuideLink(c);

  setUp(() async {
    providerHits = 0;
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('assign_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    final provider = feed({'BBCOne.uk': 'BBC One', 'Linked.uk': 'Linked'});
    final extra = feed({
      'CNN.us': 'CNN',
      'WLS-DT.us_locals1': 'WLS-DT',
      'Linked.uk': 'Linked',
      'LinkedExtra.uk': 'Totally Unknown Extra',
    });
    server.listen((req) async {
      final res = req.response;
      switch (req.uri.path) {
        case '/provider.xml':
          providerHits++;
          res.write(provider);
        case '/extra.xml.gz':
          res.add(GZipEncoder().encode(utf8.encode(extra))!);
        default:
          res.statusCode = 404;
      }
      await res.close();
    });

    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.sources).insert(SourcesCompanion.insert(
        id: 'src', nickname: 'Main', type: 'm3u', epgUrl: Value('$base/provider.xml')));
    await channel('src_ch_1', 'BBC 1 (UK)'); // provider lists it, no link
    await channel('src_ch_2', 'CNN US'); // only the extra guide has it
    await channel('src_ch_3', 'Linked', tvgId: 'Linked.uk'); // provider covers
    await channel('src_ch_4', 'Totally Unknown'); // nobody has it
    await channel('src_ch_5', 'ABC 7 CHICAGO'); // a local station
    service = GuideAssignmentService(
        db: db,
        tempDir: () async => tmp.path,
        stallTimeout: const Duration(seconds: 2));
    await db.upsertExtraGuide(ExtraGuidesCompanion.insert(
        id: 'g1', name: 'Extra', url: '$base/extra.xml.gz'));
  });

  tearDown(() async {
    await server.close(force: true);
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('links channels without a guide and loads their programmes', () async {
    final r = await service.sync();
    expect(r.errors, isEmpty);

    // The playlist's own guide file is searched first.
    expect((await link('src_ch_1'))?.guideRef, 'src:src');
    expect((await link('src_ch_1'))?.xmltvId, 'BBCOne.uk');
    // Then the extra guide.
    expect((await link('src_ch_2'))?.xmltvId, 'CNN.us');
    expect((await link('src_ch_5'))?.xmltvId, 'WLS-DT.us_locals1');
    // The provider's guide has priority: Linked.uk is never re-assigned.
    expect(await link('src_ch_3'), isNull);
    // Nothing matches: no link, no guess.
    expect(await link('src_ch_4'), isNull);

    expect(await programmesOf('src_ch_1'), 4);
    expect(await programmesOf('src_ch_2'), 4);
    expect(await programmesOf('src_ch_5'), 4);
    // ch_3 is covered by the playlist's own guide (Linked.uk): filled from it.
    expect(await programmesOf('src_ch_3'), 4);
    expect(await programmesOf('src_ch_4'), 0);

    final g = (await db.getExtraGuides()).single;
    expect(g.channelCount, 4);
    expect(g.lastError, isNull);
  });

  test('a second sync changes nothing and loses nothing', () async {
    await service.sync();
    final again = await service.sync();
    expect(again.errors, isEmpty);
    expect(await programmesOf('src_ch_2'), 4);
    expect((await db.getGuideLinks()).length, 3);
  });

  test('a manual choice beats smart assignment and the playlist guide', () async {
    await service.sync();
    await service.setManual('src_ch_4', 'ext:g1', 'CNN.us');
    await service.setManual('src_ch_3', 'ext:g1', 'CNN.us'); // over provider
    await service.sync(refreshLists: false);
    expect(await programmesOf('src_ch_4'), 4);
    expect(await programmesOf('src_ch_3'), 4);
    expect((await link('src_ch_4'))?.kind, 'manual');
  });

  test('a pick loads one channel and links it without a full sync', () async {
    await service.sync();
    expect(await service.setManualAndLoad('src_ch_4', 'ext:g1', 'CNN.us'), isNull);
    expect(await programmesOf('src_ch_4'), 4);
    expect((await link('src_ch_4'))?.kind, 'manual');
  });

  test('"no guide" removes the programmes and stays that way', () async {
    await service.sync();
    await service.setNone('src_ch_2');
    expect(await programmesOf('src_ch_2'), 0);
    await service.sync();
    expect(await programmesOf('src_ch_2'), 0);
    expect((await link('src_ch_2'))?.kind, 'manual');
  });

  test('going back to automatic brings the smart link back', () async {
    await service.sync();
    await service.setNone('src_ch_2');
    await service.resetLink('src_ch_2');
    expect(await link('src_ch_2'), isNull);
    await service.sync(refreshLists: false);
    expect((await link('src_ch_2'))?.kind, 'auto');
    expect(await programmesOf('src_ch_2'), 4);
  });

  test('smart assignment can be switched off', () async {
    SharedPreferences.setMockInitialValues({'smart_guide_assign': false});
    await service.sync();
    expect(await db.getGuideLinks(), isEmpty);
  });

  test('a guide that fails keeps what it had and says why', () async {
    await service.sync();
    await db.upsertExtraGuide(ExtraGuidesCompanion(
        id: const Value('g1'), name: const Value('Extra'), url: Value('$base/gone.xml')));
    final r = await service.sync();
    expect(r.errors, isNotEmpty);
    expect((await db.getExtraGuides()).single.lastError, isNotNull);
    expect(await programmesOf('src_ch_2'), 4); // not thrown away
    expect((await link('src_ch_2'))?.xmltvId, 'CNN.us');
  });

  test('a disabled guide is not used and removing one removes its links',
      () async {
    await service.sync();
    await db.deleteExtraGuide('g1');
    expect(await link('src_ch_2'), isNull);
    expect(await programmesOf('src_ch_2'), 0);
    expect(await db.getGuideChannels().then((l) => l.where((c) => c.guideRef == 'ext:g1')), isEmpty);
  });

  test('without extra guides or manual links nothing is linked', () async {
    await db.deleteExtraGuide('g1');
    final r = await service.sync();
    expect(r.linked, 0);
    expect(await db.getGuideLinks(), isEmpty);
  });

  test('the playlist guide is only downloaded for new links', () async {
    await service.sync(); // reads the list, then loads src_ch_1 (new link)
    expect(providerHits, 2);
    await service.sync(); // list known, src_ch_1 has programmes: no download
    expect(providerHits, 2);
    expect(await programmesOf('src_ch_1'), 4);
  });

  test('a playlist guide entry with no programmes does not count as covered',
      () async {
    // The playlist's guide lists Linked.uk but has nothing for it.
    await service.sync(); // reads the lists
    await db.markGuideProgrammes('src:src', {'BBCOne.uk'});
    expect((await db.getGuideChannels())
        .where((c) => c.guideRef == 'src:src' && c.xmltvId == 'Linked.uk')
        .single
        .hasProgrammes, isFalse);
    await service.sync(refreshLists: false);
    final l = await link('src_ch_3'); // tvg-id Linked.uk
    expect(l, isNotNull);
    expect(l!.guideRef, 'ext:g1'); // the empty provider entry is skipped
    expect(await programmesOf('src_ch_3'), 4);
  });

  test('what is known about a guide channel survives re-reading the list',
      () async {
    await service.sync();
    await db.markGuideProgrammes('src:src', {'BBCOne.uk'});
    await service.sync(); // re-reads the channel lists
    final flags = {
      for (final c in await db.getGuideChannels())
        if (c.guideRef == 'src:src') c.xmltvId: c.hasProgrammes,
    };
    expect(flags, {'BBCOne.uk': true, 'Linked.uk': false});
  });

  test('when the playlist guide takes over, its programmes are kept', () async {
    // The playlist's guide has nothing for Linked.uk, so ch_3 gets a smart link.
    await service.sync();
    await db.markGuideProgrammes('src:src', {'BBCOne.uk'});
    await service.sync(refreshLists: false);
    expect((await link('src_ch_3'))?.guideRef, 'ext:g1');
    expect(await programmesOf('src_ch_3'), 4);

    // Later the playlist's guide gets data and writes its own programmes.
    final start = DateTime.now().add(const Duration(hours: 9));
    await db.into(db.programmes).insert(ProgrammesCompanion.insert(
        channelId: 'src_ch_3',
        start: start,
        end: start.add(const Duration(hours: 1)),
        title: 'from the playlist guide'));
    await db.markGuideProgrammes('src:src', {'BBCOne.uk', 'Linked.uk'});
    await service.sync(refreshLists: false);

    expect(await link('src_ch_3'), isNull); // the smart link is gone ...
    final titles = [
      for (final p in await (db.select(db.programmes)
            ..where((t) => t.channelId.equals('src_ch_3')))
          .get())
        p.title,
    ];
    // ... and the playlist guide's programme was not thrown away with it.
    expect(titles, contains('from the playlist guide'));
  });

  test('a channel its playlist guide covers but holds nothing is refilled',
      () async {
    await service.sync(); // reads the lists
    // ch_3 has tvg-id Linked.uk, which the playlist guide lists with data;
    // lose its programmes (as "Use Automatic" or an old clean-up would).
    await db.markGuideProgrammes('src:src', {'BBCOne.uk', 'Linked.uk'});
    await db.deleteProgrammesForChannels(['src_ch_3']);
    expect(await programmesOf('src_ch_3'), 0);
    final hitsBefore = providerHits;
    await service.sync(refreshLists: false);
    expect(await programmesOf('src_ch_3'), 4); // healed from its own guide
    expect(providerHits, hitsBefore + 1);
    // Nothing left to heal: no more downloads.
    await service.sync(refreshLists: false);
    expect(providerHits, hitsBefore + 1);
  });

  test('a pick made while a sync is running is not lost or overwritten',
      () async {
    final running = service.sync();
    // Picked by hand while the first run is matching/downloading.
    await service.setManual('src_ch_4', 'ext:g1', 'CNN.us');
    final queued = service.sync(refreshLists: false, force: false);
    await running;
    await queued;
    expect((await link('src_ch_4'))?.kind, 'manual');
    expect(await programmesOf('src_ch_4'), 4);
  });

  test('automatic links never replace a manual one, even from a stale list',
      () async {
    await service.sync();
    await db.setGuideLink(GuideLinksCompanionArgs(
        channelId: 'src_ch_2',
        kind: 'manual',
        guideRef: 'ext:g1',
        xmltvId: 'CNN.us'));
    await db.replaceAutoLinks([
      GuideLinksCompanionArgs(
          channelId: 'src_ch_2',
          kind: 'auto',
          guideRef: 'src:src',
          xmltvId: 'BBCOne.uk'),
    ]);
    final l = await link('src_ch_2');
    expect(l?.kind, 'manual');
    expect(l?.xmltvId, 'CNN.us');
  });

  test('a pick that cannot be read changes nothing', () async {
    await service.sync();
    final before = await programmesOf('src_ch_2');
    expect(before, 4);
    await db.upsertExtraGuide(ExtraGuidesCompanion.insert(
        id: 'dead', name: 'Dead', url: '$base/nothing-here.xml'));
    final problem =
        await service.setManualAndLoad('src_ch_2', 'ext:dead', 'Any.us');
    expect(problem, isNotNull);
    expect(problem, contains('not changed'));
    expect((await link('src_ch_2'))?.kind, 'auto');
    expect(await programmesOf('src_ch_2'), before);
  });

  test('an extra-guide entry with no programmes gives way to one with data',
      () async {
    // Guide 1 lists NBC.us with nothing; guide 2 has real NBC data.
    final now = DateTime.now();
    final empty = '<?xml version="1.0"?><tv><channel id="NBC.us">'
        '<display-name>NBC</display-name></channel>'
        '<programme start="${stamp(now.subtract(const Duration(days: 3)))}" '
        'stop="${stamp(now.subtract(const Duration(days: 3, hours: -1)))}" '
        'channel="NBC.us"><title>old</title></programme></tv>';
    final real = feed({'NBC.us2': 'NBC'});
    await server.close(force: true);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      final res = req.response;
      if (req.uri.path == '/empty.xml') {
        res.write(empty);
      } else if (req.uri.path == '/real.xml') {
        res.write(real);
      } else {
        res.statusCode = 404;
      }
      await res.close();
    });
    await db.deleteExtraGuide('g1');
    await db.upsertExtraGuide(ExtraGuidesCompanion.insert(
        id: 'a', name: 'First', url: '$base/empty.xml', sortOrder: const Value(0)));
    await db.upsertExtraGuide(ExtraGuidesCompanion.insert(
        id: 'b', name: 'Second', url: '$base/real.xml', sortOrder: const Value(1)));
    await channel('src_ch_9', 'NBC');
    final r = await service.sync();
    expect(r.errors.where((e) => e.contains('First')), isEmpty);
    expect((await link('src_ch_9'))?.guideRef, 'ext:b');
    expect(await programmesOf('src_ch_9'), 4);
  });

  test('guides of a removed playlist and links of gone channels are dropped',
      () async {
    await service.sync();
    await db.setGuideLink(GuideLinksCompanionArgs(
        channelId: 'src_ch_2', kind: 'manual', guideRef: 'ext:g1', xmltvId: 'CNN.us'));
    await (db.delete(db.channels)..where((t) => t.id.equals('src_ch_2'))).go();
    await db.deleteOrphanGuideData();
    expect(await link('src_ch_2'), isNull);
    expect(await db.countGuideChannels('src:src'), greaterThan(0));
    await db.delete(db.channels).go();
    await (db.delete(db.sources)..where((t) => t.id.equals('src'))).go();
    await db.deleteOrphanGuideData();
    expect(await db.countGuideChannels('src:src'), 0);
  });

  test('removing a guide is safe whatever its id looks like', () async {
    await db.upsertExtraGuide(ExtraGuidesCompanion.insert(
        id: "x'; DELETE FROM programmes; --", name: 'Odd', url: '$base/extra.xml.gz'));
    await service.sync();
    final before = await db.select(db.programmes).get();
    await db.deleteExtraGuide("x'; DELETE FROM programmes; --");
    expect((await db.select(db.programmes).get()).length, before.length);
    expect((await db.getExtraGuides()).map((g) => g.id), ['g1']);
  });

  test('a guide that went quiet gives up instead of hanging', () async {
    await server.close(force: true);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    // Stops sending after a few bytes and never ends.
    server.listen((req) async {
      req.response.add(utf8.encode('<?xml version="1.0"?><tv>'));
      await req.response.flush();
    });
    // (The real stall limit is 60 s; here the app-level cap is what we can
    // check cheaply: the call must not complete normally with data.)
    await db.deleteExtraGuide('g1');
    await db.upsertExtraGuide(ExtraGuidesCompanion.insert(
        id: 'q', name: 'Quiet', url: '$base/q.xml'));
    final r = await service
        .sync()
        .timeout(const Duration(seconds: 20), onTimeout: () => throw 'hung');
    expect(r.errors, isNotEmpty);
  }, timeout: const Timeout(Duration(seconds: 40)));
}
