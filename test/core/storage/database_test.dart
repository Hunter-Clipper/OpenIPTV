import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:sqlite3/open.dart';

void main() {
  // Linux hosts often ship only the versioned runtime library (no -dev
  // symlink), which package:sqlite3 won't find by default.
  if (Platform.isLinux && File('/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }

  late AppDatabase db;
  final now = DateTime.now();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.sources).insert(
        SourcesCompanion.insert(id: 'src', nickname: 'Test', type: 'm3u'));
  });
  tearDown(() => db.close());

  Future<void> channel(String id, {int catchupDays = 0}) =>
      db.into(db.channels).insert(ChannelsCompanion.insert(
            id: id,
            sourceId: 'src',
            name: id,
            streamUrl: 'http://$id',
            catchupDays: Value(catchupDays),
          ));

  Future<void> programme(String channelId, Duration endedAgo) {
    final end = now.subtract(endedAgo);
    return db.into(db.programmes).insert(ProgrammesCompanion.insert(
          channelId: channelId,
          start: end.subtract(const Duration(minutes: 30)),
          end: end,
          title: '$channelId ${endedAgo.inHours}h',
        ));
  }

  Future<List<String>> remaining() async =>
      [for (final p in await db.select(db.programmes).get()) p.title]..sort();

  test('deleteOldProgrammes keeps each channel\'s catch-up window', () async {
    await channel('plain');
    await channel('cu1', catchupDays: 1);
    await channel('cu3', catchupDays: 3);
    for (final c in ['plain', 'cu1', 'cu3']) {
      await programme(c, const Duration(hours: 2)); // past 1h default
      await programme(c, const Duration(hours: 30)); // past 1 day
      await programme(c, const Duration(hours: 100)); // past 3 days
    }

    await db.deleteOldProgrammes();

    expect(await remaining(), ['cu1 2h', 'cu3 2h', 'cu3 30h']);
  });

  test('guide row query returns one channel\'s programmes in the window',
      () async {
    await channel('a');
    await channel('b');
    await programme('a', const Duration(minutes: -30)); // ends in 30 min
    await programme('a', const Duration(hours: 3)); // ended 3 h ago
    await programme('b', const Duration(minutes: -30));

    final result = await db.getProgrammesForChannelInRange('a',
        now.subtract(const Duration(hours: 1)), now.add(const Duration(hours: 1)));

    expect(result.map((p) => p.title), ['a 0h']);
  });

  test('searchCurrentProgrammes finds only what is airing now', () async {
    Future<void> show(String channelId, String title, Duration from,
            Duration to) =>
        db.into(db.programmes).insert(ProgrammesCompanion.insert(
              channelId: channelId,
              start: now.add(from),
              end: now.add(to),
              title: title,
            ));
    await show('a', 'The Simpsons', const Duration(minutes: -10),
        const Duration(minutes: 20));
    await show('b', 'Simpsons Marathon', const Duration(hours: 1),
        const Duration(hours: 2)); // later
    await show('c', 'Old Simpsons', const Duration(hours: -2),
        const Duration(hours: -1)); // over
    await show('d', 'News', const Duration(minutes: -5),
        const Duration(minutes: 5));

    final found = await db.searchCurrentProgrammes('SIMPSON');
    expect(found.map((p) => (p.channelId, p.title)),
        [('a', 'The Simpsons')]);
  });

  test('removing a playlist also removes its guide', () async {
    await programme('src_ch_1', const Duration(days: -1));
    await programme('src_ch_2', const Duration(days: -1));
    await programme('other_ch_1', const Duration(days: -1));
    // Not remapped yet (XMLTV id): not this playlist's to remove.
    await programme('BBC1.uk', const Duration(days: -1));

    await db.deleteProgrammesForSource('src');

    final left = await db.select(db.programmes).get();
    expect(left.map((p) => p.channelId).toSet(), {'other_ch_1', 'BBC1.uk'});
  });

  test('compact never throws, and keeps the data', () async {
    await programme('src_ch_1', const Duration(days: -1));
    await db.compact();
    expect(await db.select(db.programmes).get(), hasLength(1));
  });

  test('the guide clean-up drops programmes for channels that don\'t exist',
      () async {
    await channel('kept');
    await programme('kept', const Duration(days: -1));
    await programme('BBC1.uk', const Duration(days: -1)); // never mapped
    await db.deleteOldProgrammes();
    final left = await db.select(db.programmes).get();
    expect(left.map((p) => p.channelId), ['kept']);
  });

  test('guide ids map to this playlist\'s channels first', () async {
    await db.into(db.sources).insert(
        SourcesCompanion.insert(id: 'other', nickname: 'Other', type: 'm3u'));
    Future<void> tvg(String id, String source, String tvg) =>
        db.into(db.channels).insert(ChannelsCompanion.insert(
              id: id,
              sourceId: source,
              name: id,
              streamUrl: 'http://$id',
              tvgId: Value(tvg),
            ));
    await tvg('other_1', 'other', 'BBC1.uk');
    await tvg('src_1', 'src', 'BBC1.uk');
    await tvg('other_2', 'other', 'CNN.us');

    final ids = await db.channelIdsByTvgId('src');
    expect(ids['BBC1.uk'], 'src_1');
    expect(ids['CNN.us'], 'other_2');
    expect(ids.containsKey('ITV.uk'), isFalse);
  });
}
