import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/storage/database.dart' if (dart.library.html) 'package:open_iptv/core/storage/database_stub.dart';
import 'package:open_iptv/core/storage/local_playlists.dart';
import 'package:open_iptv/core/storage/preferences.dart';

const _schemaVersion = 3;
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

/// A backup-eligible app preference.
///
/// Each entry pairs an encode function (reads from [AppPreferences] into a
/// JSON-serializable value) with a decode function (writes a JSON-decoded
/// value back to [AppPreferences]).
///
/// To add a new backup-eligible preference:
///   1. Add a typed getter+setter pair to AppPreferences (`preferences.dart`)
///   2. Add a PreferenceEntry to [_backupPrefEntries] in BackupManager
///   3. Bump `_schemaVersion` (backward-compatible — old backups simply lack
///      the new key, which `_applySettings` skips via its null guard)
class PreferenceEntry {
  const PreferenceEntry({
    required this.key,
    required this.encode,
    required this.decode,
  });

  final String key;
  final dynamic Function(AppPreferences prefs) encode;
  final Future<void> Function(AppPreferences prefs, dynamic value) decode;
}

/// Exports/imports every profile, every source, and app-level settings as a
/// single zip archive — a full snapshot of the app's configuration, not
/// scoped to whichever profile happens to be active. The content catalog
/// (channels/movies/series/programmes) is deliberately excluded: it's
/// re-fetched from the source itself on the next refresh, so shipping it in
/// the backup would just be dead weight.
class BackupManager {
  const BackupManager({
    required this.db,
    required this.prefs,
    this.localPlaylists,
  });

  final AppDatabase db;
  final AppPreferences prefs;
  // Injectable for tests; defaults to app storage.
  final LocalPlaylists? localPlaylists;

  LocalPlaylists get _local => localPlaylists ?? LocalPlaylists();

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

    final encodedSources = [
      for (final s in sources) await _encodeSourceWithFile(s),
    ];
    final payload = jsonEncode({
      'profiles': profiles.map(_encodeProfile).toList(),
      'sources': encodedSources,
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
    final sources = [
      for (final m in (data['sources'] as List? ?? []))
        await _decodeSourceWithFile(m as Map<String, dynamic>),
    ];
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
        'accentColor': p.accentColor,
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
        accentColor: m['accentColor'] as String? ?? '0A84FF',
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
        'lastRefreshed': s.lastRefreshed?.toIso8601String(),
      };

  /// A playlist picked from the device only exists as a file in app
  /// storage, so its contents travel inside the backup (`m3uFile`) —
  /// otherwise a restore on another device would point at a missing file.
  Future<Map<String, dynamic>> _encodeSourceWithFile(Source s) async {
    final m = _encodeSource(s);
    if (LocalPlaylists.isLocal(s.m3uUrl)) {
      try {
        m['m3uFile'] = await _local.read(s.m3uUrl!);
      } on LocalPlaylistException {
        // Copy already gone: back up the rest; refresh will say so.
      }
    }
    return m;
  }

  Future<Source> _decodeSourceWithFile(Map<String, dynamic> m) async {
    final source = _decodeSource(m);
    final content = m['m3uFile'] as String?;
    if (content == null) return source;
    return source.copyWith(m3uUrl: await _local.save(source.id, content));
  }

  Source _decodeSource(Map<String, dynamic> m) => Source(
        id: m['id'] as String,
        nickname: m['nickname'] as String,
        type: m['type'] == 'xtream' ? SourceType.xtream : SourceType.m3u,
        m3uUrl: m['m3uUrl'] as String?,
        xtreamHost: m['xtreamHost'] as String?,
        xtreamUsername: m['xtreamUsername'] as String?,
        xtreamPassword: m['xtreamPassword'] as String?,
        epgUrl: m['epgUrl'] as String?,
        lastRefreshed: m['lastRefreshed'] is String
            ? DateTime.parse(m['lastRefreshed'] as String)
            : null,
      );

  // ---------------------------------------------------------------------------
  // Encoding helpers — app-level settings
  //
  // Each backup-eligible preference is registered as a [PreferenceEntry]
  // pairing an encode function (AppPreferences -> JSON value) with a decode
  // function (JSON value -> AppPreferences setter). This registry is the
  // single source of truth: to back up a new preference, add its getter/setter
  // to AppPreferences AND one entry here, then bump [_schemaVersion].
  // ---------------------------------------------------------------------------

  /// A backup-eligible app preference.
  ///
  /// To add a new backup-eligible preference:
  ///   1. Add a typed getter+setter pair to AppPreferences (`preferences.dart`)
  ///   2. Add a PreferenceEntry here with matching key, encode, and decode
  ///   3. Bump `_schemaVersion` (backward-compatible: old backups just lack
  ///      the new key, which `_applySettings` skips via its type guard)
  ///
  /// Deliberately excluded (device/session state, not user preferences):
  ///   - `activeProfileId` / `activeSourceId` — picked from the device
  ///   - `lastRegisteredRefreshIntervalHours` — WorkManager bookkeeping
  ///   - `parentalScanDone` — one-time internal flag
  ///   - `adminBiometricUnlock` — device-only (biometric enrolment)
  ///   - `recentSearches` — device-specific query history
  ///   - `lastUpdateCheck` — device-specific timestamp
  ///   - `skippedUpdateVersion` — device-specific release pin
  static final List<PreferenceEntry> _backupPrefEntries = [
    // Display
    PreferenceEntry(
      key: 'accentColor',
      encode: (p) => p.accentColor,
      decode: (p, v) async {
        if (v is String) await p.setAccentColor(v);
      },
    ),
    PreferenceEntry(
      key: 'contentSort',
      encode: (p) => p.contentSort,
      decode: (p, v) async {
        if (v is String) await p.setContentSort(v);
      },
    ),
    PreferenceEntry(
      key: 'channelListDensity',
      encode: (p) => p.channelListDensity,
      decode: (p, v) async {
        if (v is String) await p.setChannelListDensity(v);
      },
    ),
    // Views
    PreferenceEntry(
      key: 'viewModeLive',
      encode: (p) => p.viewModeLive,
      decode: (p, v) async {
        if (v is String) await p.setViewModeLive(v);
      },
    ),
    PreferenceEntry(
      key: 'viewModeMovies',
      encode: (p) => p.viewModeMovies,
      decode: (p, v) async {
        if (v is String) await p.setViewModeMovies(v);
      },
    ),
    PreferenceEntry(
      key: 'viewModeSeries',
      encode: (p) => p.viewModeSeries,
      decode: (p, v) async {
        if (v is String) await p.setViewModeSeries(v);
      },
    ),
    // Parental
    PreferenceEntry(
      key: 'parentalProtectionEnabled',
      encode: (p) => p.parentalProtectionEnabled,
      decode: (p, v) async {
        if (v is bool) await p.setParentalProtectionEnabled(v);
      },
    ),
    PreferenceEntry(
      key: 'parentalLockedCategories',
      encode: (p) => p.parentalLockedCategories,
      decode: (p, v) async {
        if (v is List) {
          await p.setParentalLockedCategories(List<String>.from(v));
        }
      },
    ),
    // Background refresh
    PreferenceEntry(
      key: 'refreshIntervalHours',
      encode: (p) => p.refreshIntervalHours,
      decode: (p, v) async {
        if (v is int) await p.setRefreshIntervalHours(v);
      },
    ),
    PreferenceEntry(
      key: 'refreshNotificationsEnabled',
      encode: (p) => p.refreshNotificationsEnabled,
      decode: (p, v) async {
        if (v is bool) await p.setRefreshNotificationsEnabled(v);
      },
    ),
    // Playback
    PreferenceEntry(
      key: 'pipEnabled',
      encode: (p) => p.pipEnabled,
      decode: (p, v) async {
        if (v is bool) await p.setPipEnabled(v);
      },
    ),
    PreferenceEntry(
      key: 'mediaNotificationEnabled',
      encode: (p) => p.mediaNotificationEnabled,
      decode: (p, v) async {
        if (v is bool) await p.setMediaNotificationEnabled(v);
      },
    ),
    // Appearance
    PreferenceEntry(
      key: 'cleanNames',
      encode: (p) => p.cleanNames,
      decode: (p, v) async {
        if (v is bool) await p.setCleanNames(v);
      },
    ),
    PreferenceEntry(
      key: 'videoFit',
      encode: (p) => p.videoFit,
      decode: (p, v) async {
        if (v is String) await p.setVideoFit(v);
      },
    ),
    PreferenceEntry(
      key: 'playerClockAlways',
      encode: (p) => p.playerClockAlways,
      decode: (p, v) async {
        if (v is bool) await p.setPlayerClockAlways(v);
      },
    ),
    // Player buffer (Power User Tools)
    PreferenceEntry(
      key: 'bufferPreset',
      encode: (p) => p.bufferPreset,
      decode: (p, v) async {
        if (v is String) await p.setBufferPreset(v);
      },
    ),
    // VPN (Power User Tools)
    PreferenceEntry(
      key: 'vpnRoute',
      encode: (p) => p.vpnRoute,
      decode: (p, v) async {
        if (v is String) await p.setVpnRoute(v);
      },
    ),
    PreferenceEntry(
      key: 'vpnAutoConnect',
      encode: (p) => p.vpnAutoConnect,
      decode: (p, v) async {
        if (v is bool) await p.setVpnAutoConnect(v);
      },
    ),
    PreferenceEntry(
      key: 'vpnKind',
      encode: (p) => p.vpnKind,
      decode: (p, v) async {
        if (v is String) await p.setVpnKind(v);
      },
    ),
    // Home layout
    PreferenceEntry(
      key: 'homeLayoutMovies',
      encode: (p) => p.homeLayoutMovies,
      decode: (p, v) async {
        if (v is String) await p.setHomeLayoutMovies(v);
      },
    ),
    PreferenceEntry(
      key: 'homeLayoutSeries',
      encode: (p) => p.homeLayoutSeries,
      decode: (p, v) async {
        if (v is String) await p.setHomeLayoutSeries(v);
      },
    ),
    // Updates
    PreferenceEntry(
      key: 'autoUpdateCheck',
      encode: (p) => p.autoUpdateCheck,
      decode: (p, v) async {
        if (v is bool) await p.setAutoUpdateCheck(v);
      },
    ),
  ];

  Map<String, dynamic> _encodeSettings() => {
        for (final entry in _backupPrefEntries) entry.key: entry.encode(prefs),
      };

  // Deliberately excludes bookkeeping-only prefs that shouldn't travel with
  // a backup: activeProfileId/activeSourceId (device/session state, not a
  // preference), lastRegisteredRefreshIntervalHours (WorkManager's own
  // internal tracking, would desync from what's actually registered on the
  // restoring device), parentalScanDone (a one-time internal flag),
  // adminBiometricUnlock (device-only biometric enrolment), recentSearches
  // (device-specific query history), lastUpdateCheck (device timestamp),
  // and skippedUpdateVersion (device-specific release pin).
  Future<void> _applySettings(Map<String, dynamic> m) async {
    for (final entry in _backupPrefEntries) {
      final value = m[entry.key];
      if (value == null) continue;
      await entry.decode(prefs, value);
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
