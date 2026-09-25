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

  test('guide range query handles more channels than SQLite can bind',
      () async {
    await channel('a');
    await programme('a', const Duration(minutes: -30)); // ends in 30 min
    final ids = ['a', for (var i = 0; i < 40000; i++) 'missing$i'];

    final result = await db.getProgrammesForChannelsInRange(
        ids, now.subtract(const Duration(hours: 1)), now.add(const Duration(hours: 1)));

    expect(result.map((p) => p.channelId), ['a']);
  });
}
