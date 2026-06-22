import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/storage/database.dart';

const _schemaVersion = 1;
const _appVersion = '1.0.0';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BackupManager {
  const BackupManager({required this.db});

  final AppDatabase db;

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<Uint8List> exportProfile(Profile profile) async {
    final sources = <Source>[];
    for (final id in profile.sourceIds) {
      final s = await db.getSourceById(id);
      if (s != null) sources.add(s);
    }

    final manifest = {
      'schema_version': _schemaVersion,
      'app_version': _appVersion,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'profile_name': profile.name,
      'encrypted': profile.hasPin,
    };

    final profileJson = _encodeProfile(profile);
    final epgMappings = {'overrides': profile.epgOverrides};

    String sourcesJson;
    if (profile.hasPin) {
      sourcesJson = _encryptJson(_encodeSources(sources), profile.pinHash!);
    } else {
      sourcesJson = _encodeSources(sources);
    }

    final archive = Archive()
      ..addFile(_jsonFile('manifest.json', manifest))
      ..addFile(_jsonFile('profile.json', jsonDecode(profileJson)))
      ..addFile(_rawFile('sources.json', utf8.encode(sourcesJson)))
      ..addFile(_jsonFile('epg_mappings.json', epgMappings));

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  Future<Profile> importProfile(
    Uint8List bytes, {
    String? pin,
  }) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    final manifestFile = _findFile(archive, 'manifest.json');
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>))
        as Map<String, dynamic>;

    final schemaVersion = manifest['schema_version'] as int? ?? 1;
    final encrypted = manifest['encrypted'] as bool? ?? false;

    if (schemaVersion > _schemaVersion) {
      throw const BackupException(
        'This backup was made with a newer version of the app. '
        'Some settings may not restore correctly.',
      );
    }

    final profileFile = _findFile(archive, 'profile.json');
    final profileData = jsonDecode(
      utf8.decode(profileFile.content as List<int>),
    ) as Map<String, dynamic>;

    final profile = _decodeProfile(profileData);

    final sourcesFile = _findFile(archive, 'sources.json');
    String sourcesJson = utf8.decode(sourcesFile.content as List<int>);

    if (encrypted) {
      if (pin == null) throw const BackupException('pin_required');
      final pinHash = sha256.convert(utf8.encode(pin)).toString();
      try {
        sourcesJson = _decryptJson(sourcesJson, pinHash);
      } catch (_) {
        throw const BackupException(
          "That PIN doesn't match this backup. Try again.",
        );
      }
    }

    final sources = _decodeSources(sourcesJson);

    // Run migration if needed.
    // ignore: unnecessary_statements
    _migrateProfile;

    // Persist.
    await db.upsertProfile(profile);
    for (final source in sources) {
      await db.upsertSource(source);
    }

    return profile;
  }

  // ---------------------------------------------------------------------------
  // Migration
  // ---------------------------------------------------------------------------

  /// Add a case for each schema version bump.
  Map<String, dynamic> _migrateProfile(
    int fromVersion,
    int toVersion,
    Map<String, dynamic> data,
  ) {
    var result = data;
    // Example: if (fromVersion < 2) { result = _migrate1to2(result); }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Encoding helpers
  // ---------------------------------------------------------------------------

  String _encodeProfile(Profile p) => jsonEncode({
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
        'createdAt': p.createdAt.toIso8601String(),
        'updatedAt': p.updatedAt.toIso8601String(),
      });

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
        customChannelOrder: Map<String, int>.from(
            m['customChannelOrder'] as Map? ?? {}),
        epgOverrides: Map<String, String>.from(
            m['epgOverrides'] as Map? ?? {}),
        hiddenCategories:
            List<String>.from(m['hiddenCategories'] as List? ?? []),
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );

  String _encodeSources(List<Source> sources) => jsonEncode(
        sources.map((s) => {
              'id': s.id,
              'nickname': s.nickname,
              'type': s.type.name,
              'm3uUrl': s.m3uUrl,
              'xtreamHost': s.xtreamHost,
              'xtreamUsername': s.xtreamUsername,
              'xtreamPassword': s.xtreamPassword,
              'epgUrl': s.epgUrl,
            }).toList(),
      );

  List<Source> _decodeSources(String json) {
    final list = jsonDecode(json) as List;
    return list.map((item) {
      final m = item as Map<String, dynamic>;
      return Source(
        id: m['id'] as String,
        nickname: m['nickname'] as String,
        type: m['type'] == 'xtream' ? SourceType.xtream : SourceType.m3u,
        m3uUrl: m['m3uUrl'] as String?,
        xtreamHost: m['xtreamHost'] as String?,
        xtreamUsername: m['xtreamUsername'] as String?,
        xtreamPassword: m['xtreamPassword'] as String?,
        epgUrl: m['epgUrl'] as String?,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Encryption (AES-256 CBC, key derived from pinHash)
  // ---------------------------------------------------------------------------

  String _encryptJson(String plaintext, String pinHash) {
    final key = enc.Key.fromUtf8(pinHash.substring(0, 32));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return jsonEncode({'iv': iv.base64, 'data': encrypted.base64});
  }

  String _decryptJson(String payload, String pinHash) {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    final key = enc.Key.fromUtf8(pinHash.substring(0, 32));
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
        "Couldn't open this backup file. Make sure it's a valid .iptvprofile file.",
      );
    }
    return file;
  }
}
