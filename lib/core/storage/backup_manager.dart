import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';

const _schemaVersion = 2;
const _appVersion = '1.0.0';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupSummary {
  const BackupSummary({required this.profileCount, required this.sourceCount});
  final int profileCount;
  final int sourceCount;
}

/// Exports/imports every profile, every source, and app-level settings as a
/// single zip archive — a full snapshot of the app's configuration, not
/// scoped to whichever profile happens to be active. The content catalog
/// (channels/movies/series/programmes) is deliberately excluded: it's
/// re-fetched from the source itself on the next refresh, so shipping it in
/// the backup would just be dead weight.
class BackupManager {
  const BackupManager({required this.db, required this.prefs});

  final AppDatabase db;
  final AppPreferences prefs;

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// [password], if provided, encrypts the archive contents. Deliberately
  /// unrelated to any profile's own PIN — a single backup can span multiple
  /// profiles with different (or no) PINs, so backup security is its own,
  /// separate concept.
  Future<Uint8List> exportAll({String? password}) async {
    final profiles = await db.getAllProfiles();
    final sources = await db.getAllSources();

    final payload = jsonEncode({
      'profiles': profiles.map(_encodeProfile).toList(),
      'sources': sources.map(_encodeSource).toList(),
      'settings': _encodeSettings(),
    });

    final hasPassword = password != null && password.isNotEmpty;
    final manifest = {
      'schema_version': _schemaVersion,
      'app_version': _appVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'encrypted': hasPassword,
      'profile_count': profiles.length,
      'source_count': sources.length,
    };

    final archive = Archive()..addFile(_jsonFile('manifest.json', manifest));
    if (hasPassword) {
      archive.addFile(
        _rawFile('data.enc', utf8.encode(_encryptJson(payload, password))),
      );
    } else {
      archive.addFile(_rawFile('data.json', utf8.encode(payload)));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  Future<BackupSummary> importAll(Uint8List bytes, {String? password}) async {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupException(
        "Couldn't open this backup file. Make sure it's a valid OpenIPTV backup.",
      );
    }

    final manifestFile = _findFile(archive, 'manifest.json');
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>))
        as Map<String, dynamic>;

    final schemaVersion = manifest['schema_version'] as int? ?? 1;
    if (schemaVersion > _schemaVersion) {
      throw const BackupException(
        'This backup was made with a newer version of the app. '
        'Update the app before restoring it.',
      );
    }
    final encrypted = manifest['encrypted'] as bool? ?? false;

    String payloadJson;
    if (encrypted) {
      if (password == null || password.isEmpty) {
        throw const BackupException('password_required');
      }
      final encFile = _findFile(archive, 'data.enc');
      try {
        payloadJson =
            _decryptJson(utf8.decode(encFile.content as List<int>), password);
      } catch (_) {
        throw const BackupException(
          "That password doesn't match this backup. Try again.",
        );
      }
    } else {
      final dataFile = _findFile(archive, 'data.json');
      payloadJson = utf8.decode(dataFile.content as List<int>);
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(payloadJson) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException(
        "Couldn't read this backup file — it may be corrupted.",
      );
    }

    final profiles = (data['profiles'] as List? ?? [])
        .map((m) => _decodeProfile(m as Map<String, dynamic>))
        .toList();
    final sources = (data['sources'] as List? ?? [])
        .map((m) => _decodeSource(m as Map<String, dynamic>))
        .toList();
    final settings = Map<String, dynamic>.from(data['settings'] as Map? ?? {});

    // Sources first — profiles reference sourceIds, and several screens read
    // sources independently too, so there's no ordering where profiles should
    // land before the sources they point at.
    for (final source in sources) {
      await db.upsertSource(source);
    }
    for (final profile in profiles) {
      await db.upsertProfile(profile);
    }
    await _applySettings(settings);

    return BackupSummary(
      profileCount: profiles.length,
      sourceCount: sources.length,
    );
  }

  // ---------------------------------------------------------------------------
  // Encoding helpers — Profile
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _encodeProfile(Profile p) => {
        'id': p.id,
        'name': p.name,
        'avatarEmoji': p.avatarEmoji,
        'pinHash': p.pinHash,
        'sourceIds': p.sourceIds,
        'favoriteChannelIds': p.favoriteChannelIds,
        'favoriteMovieIds': p.favoriteMovieIds,
        'favoriteSeriesIds': p.favoriteSeriesIds,
        'defaultCategory': p.defaultCategory,
        'channelSortOrder': p.channelSortOrder,
        'defaultSubtitleLang': p.defaultSubtitleLang,
        'defaultAudioLang': p.defaultAudioLang,
        'customChannelOrder': p.customChannelOrder,
        'epgOverrides': p.epgOverrides,
        'hiddenCategories': p.hiddenCategories,
        'isKidsProfile': p.isKidsProfile,
        'isAdmin': p.isAdmin,
        'createdAt': p.createdAt.toIso8601String(),
        'updatedAt': p.updatedAt.toIso8601String(),
      };

  Profile _decodeProfile(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        name: m['name'] as String,
        avatarEmoji: m['avatarEmoji'] as String,
        pinHash: m['pinHash'] as String?,
        sourceIds: List<String>.from(m['sourceIds'] as List? ?? []),
        favoriteChannelIds:
            List<String>.from(m['favoriteChannelIds'] as List? ?? []),
        favoriteMovieIds:
            List<String>.from(m['favoriteMovieIds'] as List? ?? []),
        favoriteSeriesIds:
            List<String>.from(m['favoriteSeriesIds'] as List? ?? []),
        defaultCategory: m['defaultCategory'] as String? ?? 'All',
        channelSortOrder: m['channelSortOrder'] as String? ?? 'provider',
        defaultSubtitleLang: m['defaultSubtitleLang'] as String? ?? '',
        defaultAudioLang: m['defaultAudioLang'] as String? ?? '',
        customChannelOrder:
            Map<String, int>.from(m['customChannelOrder'] as Map? ?? {}),
        epgOverrides: Map<String, String>.from(m['epgOverrides'] as Map? ?? {}),
        hiddenCategories:
            List<String>.from(m['hiddenCategories'] as List? ?? []),
        isKidsProfile: m['isKidsProfile'] as bool? ?? false,
        isAdmin: m['isAdmin'] as bool? ?? false,
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );

  // ---------------------------------------------------------------------------
  // Encoding helpers — Source
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _encodeSource(Source s) => {
        'id': s.id,
        'nickname': s.nickname,
        'type': s.type.name,
        'm3uUrl': s.m3uUrl,
        'xtreamHost': s.xtreamHost,
        'xtreamUsername': s.xtreamUsername,
        'xtreamPassword': s.xtreamPassword,
        'epgUrl': s.epgUrl,
      };

  Source _decodeSource(Map<String, dynamic> m) => Source(
        id: m['id'] as String,
        nickname: m['nickname'] as String,
        type: m['type'] == 'xtream' ? SourceType.xtream : SourceType.m3u,
        m3uUrl: m['m3uUrl'] as String?,
        xtreamHost: m['xtreamHost'] as String?,
        xtreamUsername: m['xtreamUsername'] as String?,
        xtreamPassword: m['xtreamPassword'] as String?,
        epgUrl: m['epgUrl'] as String?,
      );

  // ---------------------------------------------------------------------------
  // Encoding helpers — app-level settings
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _encodeSettings() => {
        'accentColor': prefs.accentColor,
        'contentSort': prefs.contentSort,
        'channelListDensity': prefs.channelListDensity,
        'viewModeLive': prefs.viewModeLive,
        'viewModeMovies': prefs.viewModeMovies,
        'viewModeSeries': prefs.viewModeSeries,
        'parentalProtectionEnabled': prefs.parentalProtectionEnabled,
        'parentalLockedCategories': prefs.parentalLockedCategories,
        'refreshIntervalHours': prefs.refreshIntervalHours,
        'refreshNotificationsEnabled': prefs.refreshNotificationsEnabled,
        'pipEnabled': prefs.pipEnabled,
        'mediaNotificationEnabled': prefs.mediaNotificationEnabled,
      };

  // Deliberately excludes bookkeeping-only prefs that shouldn't travel with
  // a backup: activeProfileId/activeSourceId (device/session state, not a
  // preference), lastRegisteredRefreshIntervalHours (WorkManager's own
  // internal tracking, would desync from what's actually registered on the
  // restoring device), and parentalScanDone (a one-time internal flag).
  Future<void> _applySettings(Map<String, dynamic> m) async {
    if (m['accentColor'] is String) {
      await prefs.setAccentColor(m['accentColor'] as String);
    }
    if (m['contentSort'] is String) {
      await prefs.setContentSort(m['contentSort'] as String);
    }
    if (m['channelListDensity'] is String) {
      await prefs.setChannelListDensity(m['channelListDensity'] as String);
    }
    if (m['viewModeLive'] is String) {
      await prefs.setViewModeLive(m['viewModeLive'] as String);
    }
    if (m['viewModeMovies'] is String) {
      await prefs.setViewModeMovies(m['viewModeMovies'] as String);
    }
    if (m['viewModeSeries'] is String) {
      await prefs.setViewModeSeries(m['viewModeSeries'] as String);
    }
    if (m['parentalProtectionEnabled'] is bool) {
      await prefs
          .setParentalProtectionEnabled(m['parentalProtectionEnabled'] as bool);
    }
    if (m['parentalLockedCategories'] is List) {
      await prefs.setParentalLockedCategories(
          List<String>.from(m['parentalLockedCategories'] as List));
    }
    if (m['refreshIntervalHours'] is int) {
      await prefs.setRefreshIntervalHours(m['refreshIntervalHours'] as int);
    }
    if (m['refreshNotificationsEnabled'] is bool) {
      await prefs.setRefreshNotificationsEnabled(
          m['refreshNotificationsEnabled'] as bool);
    }
    if (m['pipEnabled'] is bool) {
      await prefs.setPipEnabled(m['pipEnabled'] as bool);
    }
    if (m['mediaNotificationEnabled'] is bool) {
      await prefs
          .setMediaNotificationEnabled(m['mediaNotificationEnabled'] as bool);
    }
  }

  // ---------------------------------------------------------------------------
  // Encryption (AES-256 CBC, key derived from the export-time password)
  // ---------------------------------------------------------------------------

  enc.Key _deriveKey(String password) =>
      enc.Key(Uint8List.fromList(sha256.convert(utf8.encode(password)).bytes));

  String _encryptJson(String plaintext, String password) {
    final key = _deriveKey(password);
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return jsonEncode({'iv': iv.base64, 'data': encrypted.base64});
  }

  String _decryptJson(String payload, String password) {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    final key = _deriveKey(password);
    final iv = enc.IV.fromBase64(map['iv'] as String);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    return encrypter.decrypt64(map['data'] as String, iv: iv);
  }

  // ---------------------------------------------------------------------------
  // Archive helpers
  // ---------------------------------------------------------------------------

  ArchiveFile _jsonFile(String name, Object data) {
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(data));
    return ArchiveFile(name, bytes.length, bytes);
  }

  ArchiveFile _rawFile(String name, List<int> bytes) {
    return ArchiveFile(name, bytes.length, bytes);
  }

  ArchiveFile _findFile(Archive archive, String name) {
    final file = archive.findFile(name);
    if (file == null) {
      throw BackupException(
        "Couldn't open this backup file — missing $name.",
      );
    }
    return file;
  }
}
