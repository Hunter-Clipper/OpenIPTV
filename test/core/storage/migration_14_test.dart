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
    expect(version.data['user_version'], 14);
  });
}
