import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/storage/backup_manager.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/open.dart';

/// All preference keys that should survive a backup/restore round-trip.
const _expectedBackupKeys = {
  'accentColor',
  'contentSort',
  'channelListDensity',
  'viewModeLive',
  'viewModeMovies',
  'viewModeSeries',
  'parentalProtectionEnabled',
  'parentalLockedCategories',
  'refreshIntervalHours',
  'refreshNotificationsEnabled',
  'pipEnabled',
  'mediaNotificationEnabled',
  'cleanNames',
  'videoFit',
  'playerClockAlways',
  'panelTimeoutSeconds',
  'skipSeconds',
  'audioDelayMs',
  'showFavoritesCategory',
  'showRecentCategory',
  'showAllCategory',
  'guideShowNames',
  'guideTwoLineNames',
  'guideTwoLineTitles',
  'guideHighlightPlaying',
  'channelCustom',
  'fontScale',
  'overlayOpacity',
  'guideDaysAhead',
  'guideDescriptions',
  'smartGuideAssign',
  'seekKeys',
  'streamDetails',
  'lastChannelOnStart',
  'bufferPreset',
  'fullResImages',
  'vpnRoute',
  'vpnAutoConnect',
  'vpnKind',
  'homeLayoutMovies',
  'homeLayoutSeries',
  'autoUpdateCheck',
};

/// Preference keys that must NOT appear in backups (device/session state).
const _excludedPrefKeys = {
  'active_profile_id',
  'active_source_id',
  'last_registered_refresh_interval_hours',
  'parental_scan_done',
  'admin_biometric_unlock',
  'recent_searches',
  'last_update_check_ms',
  'skipped_update_version',
};

void main() {
  // The host has no libsqlite3.so dev symlink; see database_test.dart.
  if (Platform.isLinux &&
      File('/lib/x86_64-linux-gnu/libsqlite3.so.0').existsSync()) {
    open.overrideFor(
        OperatingSystem.linux, () => DynamicLibrary.open('libsqlite3.so.0'));
  }

  group('BackupManager settings', () {
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('export includes all backup-eligible preference keys', () async {
      final prefs = AppPreferences(await SharedPreferences.getInstance());
      final settings = await _encodeSettingsRaw(prefs);

      for (final key in _expectedBackupKeys) {
        expect(settings, contains(key),
            reason: 'Key "$key" missing from backup settings');
      }
    });

    test('export excludes device/session-only preference keys', () async {
      final prefs = AppPreferences(await SharedPreferences.getInstance());
      final settings = await _encodeSettingsRaw(prefs);

      for (final key in _excludedPrefKeys) {
        expect(settings, isNot(contains(key)),
            reason: '$key should not be in backup settings');
      }
    });

    test('all preferences survive export -> import round-trip', () async {
      // --- Set non-default values on the source preferences ---
      final prefs = AppPreferences(await SharedPreferences.getInstance());
      await prefs.setAccentColor('FF5722');
      await prefs.setContentSort('az');
      await prefs.setChannelListDensity('compact');
      await prefs.setViewModeLive('grid');
      await prefs.setViewModeMovies('list');
      await prefs.setViewModeSeries('list');
      await prefs.setParentalProtectionEnabled(true);
      await prefs.setParentalLockedCategories(['Adult', 'XXX']);
      await prefs.setRefreshIntervalHours(6);
      await prefs.setRefreshNotificationsEnabled(false);
      await prefs.setPipEnabled(false);
      await prefs.setMediaNotificationEnabled(false);
      await prefs.setCleanNames(false);
      await prefs.setVideoFit('fill');
      await prefs.setPlayerClockAlways(true);
      await prefs.setPanelTimeoutSeconds(8);
      await prefs.setSkipSeconds(30);
      await prefs.setAudioDelayMs(-200);
      await prefs.setSeekKeys('upDown');
      await prefs.setFontScale(1.3);
      await prefs.setShowFavoritesCategory(false);
      await prefs.setShowRecentCategory(false);
      await prefs.setShowAllCategory(false);
      await prefs.setGuideShowNames(false);
      await prefs.setGuideTwoLineNames(false);
      await prefs.setGuideTwoLineTitles(true);
      await prefs.setGuideHighlightPlaying(false);
      await prefs.setChannelCustomJson('{"p1":{"hidden":["c1"],"names":{"c2":"News"}}}');
      await prefs.setOverlayOpacity('clear');
      await prefs.setGuideDaysAhead(3);
      await prefs.setGuideDescriptions(false);
      await prefs.setSmartGuideAssign(false);
      await prefs.setStreamDetails(false);
      await prefs.setLastChannelOnStart(true);
      await prefs.setBufferPreset('large');
      await prefs.setFullResImages(false);
      await prefs.setVpnRoute('device');
      await prefs.setVpnAutoConnect(true);
      await prefs.setVpnKind('openvpn');
      await prefs.setHomeLayoutMovies('compact');
      await prefs.setHomeLayoutSeries('compact');
      await prefs.setAutoUpdateCheck(false);

      // --- Export ---
      final backup = await BackupManager(db: db, prefs: prefs).exportAll();

      // --- Verify the backup JSON contains all keys ---
      final settings = _extractSettingsFromBackup(backup);
      for (final key in _expectedBackupKeys) {
        expect(settings, contains(key),
            reason: 'Key "$key" missing from backup JSON');
      }

      // --- Import into a fresh prefs instance ---
      SharedPreferences.setMockInitialValues({});
      final prefs2 = AppPreferences(await SharedPreferences.getInstance());
      await BackupManager(db: db, prefs: prefs2).importAll(backup);

      // --- Verify every preference round-tripped ---
      expect(prefs2.accentColor, 'FF5722');
      expect(prefs2.contentSort, 'az');
      expect(prefs2.channelListDensity, 'compact');
      expect(prefs2.viewModeLive, 'grid');
      expect(prefs2.viewModeMovies, 'list');
      expect(prefs2.viewModeSeries, 'list');
      expect(prefs2.parentalProtectionEnabled, isTrue);
      expect(prefs2.parentalLockedCategories, ['Adult', 'XXX']);
      expect(prefs2.refreshIntervalHours, 6);
      expect(prefs2.refreshNotificationsEnabled, isFalse);
      expect(prefs2.pipEnabled, isFalse);
      expect(prefs2.mediaNotificationEnabled, isFalse);
      expect(prefs2.cleanNames, isFalse);
      expect(prefs2.videoFit, 'fill');
      expect(prefs2.playerClockAlways, isTrue);
      expect(prefs2.panelTimeoutSeconds, 8);
      expect(prefs2.skipSeconds, 30);
      expect(prefs2.audioDelayMs, -200);
      expect(prefs2.seekKeys, 'upDown');
      expect(prefs2.fontScale, 1.3);
      expect(prefs2.showFavoritesCategory, isFalse);
      expect(prefs2.showRecentCategory, isFalse);
      expect(prefs2.showAllCategory, isFalse);
      expect(prefs2.guideShowNames, isFalse);
      expect(prefs2.guideTwoLineNames, isFalse);
      expect(prefs2.guideTwoLineTitles, isTrue);
      expect(prefs2.guideHighlightPlaying, isFalse);
      expect(prefs2.channelCustomJson,
          '{"p1":{"hidden":["c1"],"names":{"c2":"News"}}}');
      expect(prefs2.overlayOpacity, 'clear');
      expect(prefs2.guideDaysAhead, 3);
      expect(prefs2.guideDescriptions, isFalse);
      expect(prefs2.smartGuideAssign, isFalse);
      expect(prefs2.streamDetails, isFalse);
      expect(prefs2.lastChannelOnStart, isTrue);
      expect(prefs2.bufferPreset, 'large');
      expect(prefs2.fullResImages, isFalse);
      expect(prefs2.vpnRoute, 'device');
      expect(prefs2.vpnAutoConnect, isTrue);
      expect(prefs2.vpnKind, 'openvpn');
      expect(prefs2.homeLayoutMovies, 'compact');
      expect(prefs2.homeLayoutSeries, 'compact');
      expect(prefs2.autoUpdateCheck, isFalse);
    });

    test('old schema backup (without new keys) restores without error',
        () async {
      // Simulate a schema-2 backup with only the original 12 settings
      final oldSettings = {
        'accentColor': '0A84FF',
        'contentSort': 'provider',
        'channelListDensity': 'comfortable',
        'viewModeLive': 'list',
        'viewModeMovies': 'grid',
        'viewModeSeries': 'grid',
        'parentalProtectionEnabled': false,
        'parentalLockedCategories': <String>[],
        'refreshIntervalHours': 0,
        'refreshNotificationsEnabled': true,
        'pipEnabled': true,
        'mediaNotificationEnabled': true,
        // cleanNames, videoFit, playerClockAlways, bufferPreset, vpnRoute,
        // vpnAutoConnect, vpnKind, homeLayoutMovies, homeLayoutSeries,
        // autoUpdateCheck are deliberately absent (old schema-2 backup)
      };

      final oldBackup = _buildOldSchemaBackup(oldSettings);

      // Should not throw — missing keys are silently skipped
      SharedPreferences.setMockInitialValues({});
      final prefs2 = AppPreferences(await SharedPreferences.getInstance());
      await BackupManager(db: db, prefs: prefs2).importAll(oldBackup);

      // Old keys should be restored
      expect(prefs2.accentColor, '0A84FF');
      expect(prefs2.contentSort, 'provider');

      // New keys should get their defaults (no crash)
      expect(prefs2.cleanNames, isTrue);
      expect(prefs2.videoFit, 'fit');
      expect(prefs2.vpnRoute, 'app');
    });
  });

  test('extra guides and hand-picked guide links survive a backup', () async {
    final db1 = AppDatabase(NativeDatabase.memory());
    final prefs1 = AppPreferences(await SharedPreferences.getInstance());
    await db1.upsertExtraGuide(ExtraGuidesCompanion.insert(
        id: 'g1', name: 'Locals', url: 'http://example.test/g.xml.gz'));
    await db1.setGuideLink(const GuideLinksCompanionArgs(
        channelId: 'a_ch_1',
        kind: 'manual',
        guideRef: 'ext:g1',
        xmltvId: 'WNBC-DT.us'));
    await db1.setGuideLink(
        const GuideLinksCompanionArgs(channelId: 'a_ch_2', kind: 'manual'));
    await db1.setGuideLink(const GuideLinksCompanionArgs(
        channelId: 'a_ch_3',
        kind: 'auto',
        guideRef: 'ext:g1',
        xmltvId: 'CNN.us'));
    final bytes = await BackupManager(db: db1, prefs: prefs1).exportAll();
    await db1.close();

    final db2 = AppDatabase(NativeDatabase.memory());
    await BackupManager(db: db2, prefs: prefs1).importAll(bytes);
    expect((await db2.getExtraGuides()).single.url, 'http://example.test/g.xml.gz');
    final links = {for (final l in await db2.getGuideLinks()) l.channelId: l};
    expect(links['a_ch_1']?.xmltvId, 'WNBC-DT.us');
    expect(links['a_ch_2']?.xmltvId, isNull);
    expect(links['a_ch_2']?.kind, 'manual');
    expect(links.containsKey('a_ch_3'), isFalse); // automatic: recomputed
    await db2.close();
  });
}

/// Encodes settings by exporting through BackupManager and extracting
/// the JSON settings map. This is a behavioral test — if a preference
/// is registered it must appear in the export.
Future<Map<String, dynamic>> _encodeSettingsRaw(AppPreferences prefs) async {
  final db = AppDatabase(NativeDatabase.memory());
  final backup = await BackupManager(db: db, prefs: prefs).exportAll();
  await db.close();
  return _extractSettingsFromBackup(backup);
}

/// Extracts the settings map from a backup ZIP.
Map<String, dynamic> _extractSettingsFromBackup(Uint8List backup) {
  final archive = ZipDecoder().decodeBytes(backup);
  final dataFile = archive.findFile('data.json');
  if (dataFile == null) {
    throw StateError('data.json not found in backup');
  }
  final payload = utf8.decode(dataFile.content as List<int>);
  final json = jsonDecode(payload) as Map<String, dynamic>;
  return json['settings'] as Map<String, dynamic>;
}

/// Builds a schema-2 backup bytes with only the old 12 settings (no new keys).
Uint8List _buildOldSchemaBackup(Map<String, dynamic> settings) {
  final payload =
      jsonEncode({'profiles': [], 'sources': [], 'settings': settings});

  final manifest = jsonEncode({
    'schema_version': 2,
    'app_version': '1.0.0',
    'created_at': '2026-01-01T00:00:00.000Z',
    'encrypted': false,
    'profile_count': 0,
    'source_count': 0,
  });

  final archive = Archive()
    ..addFile(ArchiveFile(
        'manifest.json', utf8.encode(manifest).length, utf8.encode(manifest)))
    ..addFile(ArchiveFile(
        'data.json', utf8.encode(payload).length, utf8.encode(payload)));

  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}
