// Native (Android) connection to the app database: encrypted SQLite on disk.
// The web build uses database_connection_web.dart instead.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:open_iptv/core/storage/db_encryption.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

// Top-level so Isolate.spawn can send it across isolate boundaries.
void _dbSetup(Database db) {
  // Wait for another connection's write before failing with SQLITE_BUSY:
  // the background auto-refresh swaps a playlist's list in one transaction
  // (~10 s for 76k movies on a phone, longer on a TV), and the app's
  // progress saves must queue behind it, not fail. Reads never wait (WAL).
  // Must be set before migrations run.
  db.execute('PRAGMA busy_timeout = 60000;');
  // The write-ahead log grows to the size of the biggest write (a playlist
  // swap, a guide import) and SQLite never shrinks it on its own — on a TV
  // it reached over a gigabyte. Cap what it keeps after each checkpoint.
  db.execute('PRAGMA journal_size_limit = 33554432;');
  // Space freed by a refresh can be handed back to the device ([compact]).
  // Takes effect on a new database right away; an existing one switches
  // over once, in [compactIfBloated].
  db.execute('PRAGMA auto_vacuum = INCREMENTAL;');
}

/// The app database, encrypted on disk (see db_encryption.dart). The
/// background auto-refresh isolate passes `migrate: false` so it never
/// races the app converting an older unencrypted database.
QueryExecutor openAppConnection({bool migrate = true}) {
  return LazyDatabase(() async {
    final prefs = await SharedPreferences.getInstance();
    final skipEncryption =
        prefs.getBool(kSkipDbEncryptionKey) ?? false;
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'open_iptv.db'));
    if (skipEncryption) {
      // Plain SQLite — no encryption overhead. Mirror _plain() so the
      // background isolate loads the bundled SQLite library on Android.
      if (file.existsSync() && !isPlaintextSqlite(file)) {
        // Existing encrypted DB: convert in place before opening plain.
        if (!migrate) {
          throw const DatabaseNotReadyException();
        }
        final key = await DbKeyStore().read();
        if (key != null && keyOpens(file.path, key)) {
          try {
            await Isolate.run(() => decryptInPlace(file.path, key));
          } catch (_) {
            debugPrint('[OTV-db] decrypt failed, setting aside old database');
            setAside(file);
          }
        } else {
          debugPrint('[OTV-db] key does not open encrypted db, setting aside');
          setAside(file);
        }
      }
      debugPrint('[OTV-db] opened (plaintext, skip encryption)');
      if (migrate) unawaited(_logStorage(dbFolder));
      return NativeDatabase.createInBackground(file,
          isolateSetup: useSqlCipher, setup: _dbSetup);
    }
    final (executor, state) = await openEncryptedDatabase(
      file,
      keys: DbKeyStore(),
      setup: _dbSetup,
      migrate: migrate,
    );
    debugPrint('[OTV-db] opened (${state.name})');
    if (migrate) unawaited(_logStorage(dbFolder));
    return executor;
  });
}

/// Logs every file over 1 MB in the app's folders (sizes only), so storage
/// growth on a device can be traced with `adb logcat | grep OTV-storage`.
Future<void> _logStorage(Directory documents) async {
  try {
    final dirs = <Directory>{
      documents,
      await getApplicationSupportDirectory(),
      await getTemporaryDirectory(),
    };
    for (final dir in dirs) {
      var total = 0;
      final big = <String>[];
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final size = await e.length();
        total += size;
        if (size > 1 << 20) {
          big.add('${p.relative(e.path, from: dir.path)} '
              '${(size / (1 << 20)).toStringAsFixed(1)} MB');
        }
      }
      debugPrint('[OTV-storage] ${p.basename(dir.path)}: '
          '${(total / (1 << 20)).toStringAsFixed(1)} MB'
          '${big.isEmpty ? '' : ' — ${big.join(', ')}'}');
    }
  } catch (e) {
    debugPrint('[OTV-storage] report failed: $e');
  }
}
