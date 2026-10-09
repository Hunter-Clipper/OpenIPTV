import 'dart:ffi';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/storage/db_encryption.dart';
import 'package:open_iptv/shared/utils/redact.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  if (Platform.isLinux &&
      File('/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }

  group('DbKeyStore', () {
    test('creates a 256-bit key once and reuses it', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = DbKeyStore();
      final key = await store.obtain();
      expect(DbKeyStore.isValidKey(key), isTrue);
      expect(await store.obtain(), key);
      expect(await DbKeyStore().read(), key);
    });

    test('keys are random', () {
      expect(DbKeyStore.newKey(), isNot(DbKeyStore.newKey()));
    });

    test('a damaged stored key is replaced', () async {
      FlutterSecureStorage.setMockInitialValues({'otv_db_key_v1': 'oops'});
      final key = await DbKeyStore().obtain();
      expect(DbKeyStore.isValidKey(key), isTrue);
    });
  });

  test('recognises an unencrypted database file', () {
    final dir = Directory.systemTemp.createTempSync('otv_db');
    addTearDown(() => dir.deleteSync(recursive: true));
    final plain = File('${dir.path}/plain.db');
    sqlite3.open(plain.path)
      ..execute('CREATE TABLE t (x)')
      ..dispose();
    expect(isPlaintextSqlite(plain), isTrue);

    final random = File('${dir.path}/enc.db')
      ..writeAsBytesSync(List<int>.generate(4096, (i) => (i * 37) % 251));
    expect(isPlaintextSqlite(random), isFalse);
    expect(isPlaintextSqlite(File('${dir.path}/missing.db')), isFalse);
  });

  test('background isolates never open an unconverted database', () async {
    final dir = Directory.systemTemp.createTempSync('otv_db');
    addTearDown(() => dir.deleteSync(recursive: true));
    final plain = File('${dir.path}/open_iptv.db');
    sqlite3.open(plain.path)
      ..execute('CREATE TABLE t (x)')
      ..dispose();
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(
      openEncryptedDatabase(plain,
          keys: DbKeyStore(), setup: (_) {}, migrate: false),
      throwsA(isA<DatabaseNotReadyException>()),
    );
    expect(isPlaintextSqlite(plain), isTrue, reason: 'left untouched');
  });

  group('a key that cannot be read (#51)', () {
    late Directory dir;
    late File db;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('otv_db');
      db = File('${dir.path}/open_iptv.db')
        ..writeAsBytesSync(List<int>.generate(4096, (i) => (i * 37) % 251));
      File('${db.path}-wal').writeAsStringSync('wal');
      FlutterSecureStorage.setMockInitialValues({});
    });
    tearDown(() => dir.deleteSync(recursive: true));

    Future<bool> anyKeyOpens(String path, String key) async => true;

    test('a passing read failure is retried, and nothing is reset', () async {
      final keys = _FlakyKeys(failures: 3, key: DbKeyStore.newKey());
      final (_, state) = await openEncryptedDatabase(db,
          keys: keys,
          setup: (_) {},
          keyOpens: anyKeyOpens,
          retryDelay: Duration.zero);
      expect(state, DbOpenState.encrypted);
      expect(keys.reads, 4);
      expect(db.existsSync(), isTrue);
      expect(File('${db.path}$lostSuffix').existsSync(), isFalse);
    });

    test('the background refresh never resets the database', () async {
      final keys = _FlakyKeys(failures: 99);
      await expectLater(
        openEncryptedDatabase(db,
            keys: keys,
            setup: (_) {},
            migrate: false,
            keyOpens: anyKeyOpens,
            retryDelay: Duration.zero),
        throwsA(isA<DatabaseNotReadyException>()),
      );
      expect(db.existsSync(), isTrue, reason: 'left untouched');
    });

    test('a lost key sets the old database aside instead of deleting it',
        () async {
      final before = db.readAsBytesSync();
      final keys = _FlakyKeys(failures: 99);
      final (_, state) = await openEncryptedDatabase(db,
          keys: keys,
          setup: (_) {},
          keyOpens: anyKeyOpens,
          retryDelay: Duration.zero);
      expect(state, DbOpenState.reset);
      expect(File('${db.path}$lostSuffix').readAsBytesSync(), before);
      expect(File('${db.path}$lostSuffix-wal').existsSync(), isTrue);
      expect(db.existsSync(), isFalse);
    });

    test('a key that does not match also sets it aside; one set is kept',
        () async {
      File('${db.path}$lostSuffix').writeAsStringSync('older');
      final keys = _FlakyKeys(failures: 0, key: DbKeyStore.newKey());
      final (_, state) = await openEncryptedDatabase(db,
          keys: keys,
          setup: (_) {},
          keyOpens: (_, __) async => false,
          retryDelay: Duration.zero);
      expect(state, DbOpenState.reset);
      expect(File('${db.path}$lostSuffix').lengthSync(), 4096);
    });
  });

  group('redactUrl', () {
    test('masks Xtream path logins', () {
      expect(redactUrl('http://h:80/live/alice/s3cr3t/42.ts'),
          'http://h:80/live/***/***/42.ts');
      expect(redactUrl('http://h/movie/a/b/1.mp4'), 'http://h/movie/***/***/1.mp4');
    });

    test('masks query and userinfo logins', () {
      expect(redactUrl('http://h/xmltv.php?username=alice&password=s3cr3t'),
          'http://h/xmltv.php?username=***&password=***');
      expect(redactUrl('http://alice:s3cr3t@h/list.m3u'),
          'http://***@h/list.m3u');
    });

    test('leaves ordinary links alone', () {
      const url = 'https://iptv-org.github.io/iptv/index.m3u';
      expect(redactUrl(url), url);
    });
  });
}

/// A key store whose first [failures] reads throw.
class _FlakyKeys extends DbKeyStore {
  _FlakyKeys({required this.failures, this.key});

  final int failures;
  final String? key;
  int reads = 0;

  @override
  Future<String?> read() async {
    reads++;
    if (reads <= failures) throw Exception('keystore busy');
    return key;
  }
}
