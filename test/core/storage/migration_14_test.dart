import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:sqlite3/open.dart';

void main() {
  if (Platform.isLinux &&
      File('/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }

  // The UI and the background engine can both start the upgrade; the second
  // one finds the new columns already there and must not fail.
  test('upgrading to 14 tolerates columns that already exist', () async {
    final dir = await Directory.systemTemp.createTemp('otv-mig14');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/test.db');

    var db = AppDatabase(NativeDatabase(file));
    await db.customStatement('SELECT 1'); // creates the current schema
    await db.customStatement('PRAGMA user_version = 13');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await db.getAllSources(), isEmpty); // forces open + upgrade
    final version =
        await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data['user_version'], 16); // upgrades on to the latest
  });

  // Extra guides (#40): an upgrade from 14 creates the three tables, and a
  // second engine finding them already there must not fail.
  test('upgrading to 15 creates the guide tables, even if they exist', () async {
    final dir = await Directory.systemTemp.createTemp('otv-mig15');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/test.db');

    var db = AppDatabase(NativeDatabase(file));
    await db.customStatement('SELECT 1');
    for (final t in ['extra_guides', 'guide_channels', 'channel_guide_links']) {
      await db.customStatement('DROP TABLE $t');
    }
    await db.customStatement('PRAGMA user_version = 14');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    expect(await db.getExtraGuides(), isEmpty);
    expect(await db.getGuideLinks(), isEmpty);
    expect(await db.getGuideChannels(), isEmpty);
    await db.close();

    // Tables already present while the version still says 14.
    final raw = AppDatabase(NativeDatabase(file));
    await raw.customStatement('PRAGMA user_version = 14');
    await raw.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(await db.getExtraGuides(), isEmpty);
  });

  // 16 adds guide_channels.has_programmes.
  test('upgrading to 16 adds the column, and tolerates it being there', () async {
    final dir = await Directory.systemTemp.createTemp('otv-mig16');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/test.db');

    var db = AppDatabase(NativeDatabase(file));
    await db.customStatement('SELECT 1');
    await db.customStatement('ALTER TABLE guide_channels DROP COLUMN has_programmes');
    await db.customStatement('PRAGMA user_version = 15');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    await db.replaceGuideChannels('ext:x', [(id: 'A', name: 'A')]);
    await db.markGuideProgrammes('ext:x', {'A'});
    expect((await db.getGuideChannels()).single.hasProgrammes, isTrue);
    await db.close();

    final raw = AppDatabase(NativeDatabase(file));
    await raw.customStatement('PRAGMA user_version = 15');
    await raw.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect((await db.getGuideChannels()).single.xmltvId, 'A');
  });
}
