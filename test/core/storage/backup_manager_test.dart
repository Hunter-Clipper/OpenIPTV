import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/storage/backup_manager.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  'bufferPreset',
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
      await prefs.setBufferPreset('large');
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
      expect(prefs2.bufferPreset, 'large');
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
