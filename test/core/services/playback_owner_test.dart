import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:sqlite3/open.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux &&
      File('/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }

  late AppDatabase db;
  final opened = <String>[];

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    opened.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('openiptv/video_player'), (call) async {
      if (call.method == 'create') return 1;
      if (call.method == 'open') {
        opened.add((call.arguments as Map)['url'] as String);
      }
      return null;
    });
    // The player's event stream: nothing to send.
    messenger.setMockMethodCallHandler(
        const MethodChannel('openiptv/video_player_events/1'), (_) async => null);
  });

  tearDown(() => db.close());

  test('the last play() decides who owns the shared player', () async {
    final service = PlaybackService(db: db);
    final phone = Object();
    final car = Object();

    await service.play('http://example.test/phone.ts', owner: phone);
    expect(service.owner, same(phone));

    // Android Auto picks something else: the phone's screen must see that
    // it no longer owns the player (and stop reconnecting to its stream).
    await service.play('http://example.test/car.ts', owner: car);
    expect(service.owner, same(car));
    expect(identical(service.owner, phone), isFalse);
    expect(opened, ['http://example.test/phone.ts', 'http://example.test/car.ts']);
  });

  test('a play() without an owner clears the previous one', () async {
    final service = PlaybackService(db: db);
    await service.play('http://example.test/a.ts', owner: Object());
    await service.play('http://example.test/b.ts');
    expect(service.owner, isNull);
  });
}
