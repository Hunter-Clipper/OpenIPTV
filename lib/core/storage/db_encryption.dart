import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// On-device encryption of the app database (playlist logins, and the
/// stream links that embed them).
///
/// The whole database is a SQLCipher file (AES-256, page-level, HMAC
/// authenticated) unlocked by a random 256-bit key. That key never leaves the
/// device: it is created with a secure random generator on first launch and
/// kept in [FlutterSecureStorage], which on Android wraps it with a
/// non-exportable key in the hardware-backed Android Keystore. Other apps
/// can't read it, and a copy of the database file on its own is useless.
///
/// App data is also excluded from Android cloud / device-transfer backups
/// (AndroidManifest) — a restored database would have no matching key. The
/// app's own Backup & Restore (optionally password-protected) is the way to
/// move a setup between devices.
class DbKeyStore {
  DbKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'otv_db_key_v1';

  final FlutterSecureStorage _storage;

  /// The database key (64 hex characters), creating it on first use.
  Future<String> obtain() async =>
      await read() ?? await _create();

  Future<String?> read() async {
    final key = await _storage.read(key: _keyName);
    return key != null && isValidKey(key) ? key : null;
  }

  Future<String> _create() async {
    final key = newKey();
    await _storage.write(key: _keyName, value: key);
    return key;
  }

  Future<void> delete() => _storage.delete(key: _keyName);

  static String newKey() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static bool isValidKey(String key) =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(key);
}

/// Raw-key form for PRAGMA key / ATTACH … KEY (skips the passphrase KDF —
/// the key is already 256 bits of randomness).
String _sqlKey(String hexKey) => "\"x'$hexKey'\"";

/// True when [file] is an ordinary, unencrypted SQLite database (its first
/// 16 bytes are the SQLite magic header; SQLCipher files look random).
bool isPlaintextSqlite(File file) {
  if (!file.existsSync() || file.lengthSync() < 16) return false;
  final raf = file.openSync();
  try {
    final header = raf.readSync(16);
    return listEquals(header, _sqliteMagic);
  } finally {
    raf.closeSync();
  }
}

final _sqliteMagic =
    Uint8List.fromList('SQLite format 3\u0000'.codeUnits);

void _useSqlCipher() {
  open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
}

/// Thrown to background isolates while the database hasn't been converted
/// to encrypted yet — they skip their run; the app converts it on launch.
class DatabaseNotReadyException implements Exception {
  const DatabaseNotReadyException();

  @override
  String toString() => 'DatabaseNotReadyException';
}

enum DbOpenState {
  /// Opened encrypted (new install, already encrypted, or just converted).
  encrypted,

  /// Conversion failed this time; opened unencrypted, retried next launch.
  plaintext,

  /// The key didn't match the file (lost from the Keystore); the old
  /// database was deleted and a fresh one created.
  reset,
}

/// Opens [file] as the app database, encrypting a pre-existing plaintext
/// database first when [migrate] is true. Background isolates (auto-refresh)
/// pass false: they never convert, and never touch an unconverted file
/// ([DatabaseNotReadyException]).
Future<(QueryExecutor, DbOpenState)> openEncryptedDatabase(
  File file, {
  required DbKeyStore keys,
  required void Function(Database db) setup,
  bool migrate = true,
}) async {
  _useSqlCipher();
  await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();

  var state = DbOpenState.encrypted;
  if (isPlaintextSqlite(file)) {
    // Never open the old file from a background isolate: the app may be
    // converting it at this very moment, and writes to the old file would
    // be lost (or caught half-done in the converted copy).
    if (!migrate) throw const DatabaseNotReadyException();
    final key = await keys.obtain();
    try {
      final sw = Stopwatch()..start();
      await Isolate.run(() => _encryptInPlace(file.path, key));
      debugPrint('[OTV-db] encrypted existing database in '
          '${sw.elapsedMilliseconds}ms');
    } catch (e) {
      debugPrint('[OTV-db] encryption failed, staying unencrypted: $e');
      return (_plain(file, setup), DbOpenState.plaintext);
    }
  }

  var key = await keys.read();
  if (file.existsSync()) {
    final ok = key != null &&
        await Isolate.run(() => _keyOpens(file.path, key!));
    if (!ok) {
      // Unrecoverable without the key — start clean (the user can restore
      // one of their own backups from the setup screen).
      debugPrint('[OTV-db] database key missing or wrong — resetting');
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final f = File('${file.path}$suffix');
        if (f.existsSync()) f.deleteSync();
      }
      await keys.delete();
      key = null;
      state = DbOpenState.reset;
    }
  }
  key ??= await keys.obtain();

  final sqlKey = _sqlKey(key);
  return (
    NativeDatabase.createInBackground(
      file,
      isolateSetup: _useSqlCipher,
      setup: (db) {
        db.execute('PRAGMA key = $sqlKey;');
        setup(db);
      },
    ),
    state,
  );
}

QueryExecutor _plain(File file, void Function(Database) setup) =>
    NativeDatabase.createInBackground(file,
        isolateSetup: _useSqlCipher, setup: setup);

const _sqliteNotADb = 26;

bool _keyOpens(String path, String hexKey) {
  _useSqlCipher();
  final db = sqlite3.open(path);
  try {
    db.execute('PRAGMA key = ${_sqlKey(hexKey)};');
    db.select('SELECT count(*) FROM sqlite_master;');
    return true;
  } on SqliteException catch (e) {
    // Only "file is not a database" means the key is wrong. Anything else
    // (busy, locked, I/O) is left for the real open to retry or report —
    // it must never cause the reset below.
    return e.resultCode != _sqliteNotADb;
  } finally {
    db.dispose();
  }
}

/// Rewrites the plaintext database at [path] as a SQLCipher database with
/// [hexKey], replacing the original only once the copy is complete.
void _encryptInPlace(String path, String hexKey) {
  _useSqlCipher();
  final tmp = '$path.encrypting';
  for (final f in [File(tmp), File('$tmp-journal')]) {
    if (f.existsSync()) f.deleteSync();
  }
  final db = sqlite3.open(path);
  try {
    if (db.select('PRAGMA cipher_version;').isEmpty) {
      throw StateError('SQLCipher is not available');
    }
    db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    final version = db.select('PRAGMA user_version;').first.values.first;
    db.execute("ATTACH DATABASE '$tmp' AS enc KEY ${_sqlKey(hexKey)};");
    db.select("SELECT sqlcipher_export('enc');");
    // sqlcipher_export copies the schema and rows, not the header field
    // drift keeps its schema version in.
    db.execute('PRAGMA enc.user_version = $version;');
    db.execute('DETACH DATABASE enc;');
  } catch (_) {
    db.dispose();
    final t = File(tmp);
    if (t.existsSync()) t.deleteSync();
    rethrow;
  }
  db.dispose();
  for (final suffix in ['-wal', '-shm', '-journal']) {
    final f = File('$path$suffix');
    if (f.existsSync()) f.deleteSync();
  }
  File(tmp).renameSync(path);
}
