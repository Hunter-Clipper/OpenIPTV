import 'dart:ffi';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/backup_manager.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

void main() {
  if (Platform.isLinux &&
      File('/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }

  late AppDatabase db;
  late ProfileService service;
  late String profileId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    service = ProfileService(db: db);
    profileId = (await service.createProfile(name: 'Me', avatarEmoji: '🏠')).id;
  });
  tearDown(() => db.close());

  Future<List<String>> order() async =>
      (await db.getProfileById(profileId))!.categoryOrder;
  Future<Map<String, String>> names() async =>
      (await db.getProfileById(profileId))!.categoryNames;

  test('a new profile starts with the provider names and order', () async {
    expect(await names(), isEmpty);
    expect(await order(), isEmpty);
  });

  test('rename saves a custom name; empty or unchanged removes it', () async {
    await service.renameCategory(profileId, 'UK - Entertainment', ' Watch Together ');
    expect(await names(), {'UK - Entertainment': 'Watch Together'});

    await service.renameCategory(profileId, 'UK - Entertainment', '   ');
    expect(await names(), isEmpty);

    await service.renameCategory(profileId, 'News', 'Headlines');
    await service.renameCategory(profileId, 'News', 'News');
    expect(await names(), isEmpty);

    await service.renameCategory(profileId, 'News', 'Headlines');
    await service.renameCategory(profileId, 'News', null);
    expect(await names(), isEmpty);
  });

  test('move saves the order the user sees', () async {
    await service.moveCategory(profileId, ['A', 'B', 'C'], 'C', -1);
    expect(await order(), ['A', 'C', 'B']);
    await service.moveCategory(profileId, ['A', 'C', 'B'], 'A', 1);
    expect(await order(), ['C', 'A', 'B']);
  });

  test('reset clears names and order but not hidden categories', () async {
    await service.hideCategory(profileId, 'Hidden');
    await service.renameCategory(profileId, 'A', 'Aye');
    await service.moveCategory(profileId, ['A', 'B'], 'B', -1);
    await service.resetCategoryCustomisation(profileId);
    expect(await names(), isEmpty);
    expect(await order(), isEmpty);
    expect((await db.getProfileById(profileId))!.hiddenCategories, ['Hidden']);
  });

  test('names, order and live format survive a backup and restore', () async {
    await service.renameCategory(profileId, 'A', 'Aye');
    await service.moveCategory(profileId, ['A', 'B'], 'B', -1);
    await db.upsertSource(const Source(
      id: 's1',
      nickname: 'Main',
      type: SourceType.xtream,
      xtreamHost: 'http://example.test',
      xtreamUsername: 'u',
      xtreamPassword: 'p',
      liveFormat: 'hls',
    ));
    final prefs = AppPreferences(await SharedPreferences.getInstance());
    final backup = await BackupManager(db: db, prefs: prefs).exportAll();

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await BackupManager(db: other, prefs: prefs).importAll(backup);

    final restored = (await other.getAllProfiles()).single;
    expect(restored.categoryNames, {'A': 'Aye'});
    expect(restored.categoryOrder, ['B', 'A']);
    expect((await other.getSourceById('s1'))!.liveFormat, 'hls');
  });
}
