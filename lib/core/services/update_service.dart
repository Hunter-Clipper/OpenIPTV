import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Where release info comes from: the GitHub releases API for this repo.
/// Overridable at build time (`--dart-define=OPENIPTV_UPDATE_FEED=…`) so the
/// update flow can be exercised against a local test feed.
const _updateFeedUrl = String.fromEnvironment(
  'OPENIPTV_UPDATE_FEED',
  defaultValue:
      'https://api.github.com/repos/Hunter-Clipper/OpenIPTV/releases/latest',
);

/// Stable link to the newest APK — used if a release lists no APK asset.
const latestApkUrl =
    'https://github.com/Hunter-Clipper/OpenIPTV/releases/latest/download/app-release.apk';

const _playStoreInstaller = 'com.android.vending';

/// A semantic version (major.minor.patch); anything after the numbers
/// (`+build`, `-beta`) is ignored for comparison.
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static final _pattern = RegExp(r'^\s*v?(\d+)(?:\.(\d+))?(?:\.(\d+))?');

  /// Parses "0.10.45", "v0.10.45", "0.10.45+1". Returns null if unparseable.
  static AppVersion? tryParse(String? text) {
    final m = _pattern.firstMatch(text ?? '');
    if (m == null) return null;
    int part(int i) => int.tryParse(m.group(i) ?? '0') ?? 0;
    return AppVersion(part(1), part(2), part(3));
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// The latest published release.
@immutable
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.title,
    required this.notes,
    required this.apkUrl,
    this.apkSize,
  });

  /// Builds from a GitHub `releases/latest` response. Returns null if it has
  /// no usable version tag.
  static UpdateInfo? fromGitHubJson(Map<String, dynamic> json) {
    final version = AppVersion.tryParse(json['tag_name'] as String?);
    if (version == null) return null;
    String apkUrl = latestApkUrl;
    int? apkSize;
    for (final a in (json['assets'] as List<dynamic>? ?? const [])) {
      final asset = a as Map<String, dynamic>;
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apkUrl = asset['browser_download_url'] as String? ?? apkUrl;
        apkSize = (asset['size'] as num?)?.toInt();
        break;
      }
    }
    return UpdateInfo(
      version: version,
      title: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'v$version',
      notes: (json['body'] as String? ?? '').trim(),
      apkUrl: apkUrl,
      apkSize: apkSize,
    );
  }

  final AppVersion version;
  final String title;
  // The release's changelog (GitHub-flavoured Markdown).
  final String notes;
  final String apkUrl;
  final int? apkSize;
}

/// Finds, downloads and installs app updates for sideloaded installs (Fire
/// TV via Downloader, other Android devices without Google Play). Play Store
/// installs are left to the store.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  static const _channel = MethodChannel('openiptv/updates');

  final http.Client _client;

  Future<AppVersion?> installedVersion() async =>
      AppVersion.tryParse((await PackageInfo.fromPlatform()).version);

  /// Whether this install should self-update at all (false for Play Store
  /// installs, and on non-Android platforms).
  Future<bool> isSelfUpdatable() async {
    if (!Platform.isAndroid) return false;
    try {
      final installer =
          await _channel.invokeMethod<String>('installerPackage');
      return installer != _playStoreInstaller;
    } on PlatformException {
      return true;
    }
  }

  /// The latest release, or null if the check failed. Anonymous request — no
  /// device or user identifiers are sent.
  Future<UpdateInfo?> fetchLatest() async {
    try {
      final response = await _client.get(
        Uri.parse(_updateFeedUrl),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'OpenIPTV-updater',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      return UpdateInfo.fromGitHubJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[OTV-update] check failed: $e');
      return null;
    }
  }

  /// The latest release if it's newer than what's installed, else null.
  Future<UpdateInfo?> checkForUpdate() async {
    final (latest, installed) = await (fetchLatest(), installedVersion()).wait;
    if (latest == null || installed == null) return null;
    return latest.version > installed ? latest : null;
  }

  Future<bool> canInstallPackages() async {
    try {
      return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> openInstallPermissionSettings() =>
      _channel.invokeMethod('openInstallPermissionSettings');

  /// Downloads the update APK into the app cache (the directory the native
  /// FileProvider exposes), reporting progress as 0..1 when the size is known.
  Future<File> download(UpdateInfo info,
      {void Function(double? progress)? onProgress}) async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (dir.existsSync()) dir.deleteSync(recursive: true); // stale downloads
    dir.createSync(recursive: true);
    final file = File('${dir.path}/OpenIPTV-${info.version}.apk');

    final response = await _client
        .send(http.Request('GET', Uri.parse(info.apkUrl)))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw HttpException('http_${response.statusCode}');
    }
    final total = response.contentLength ?? info.apkSize;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(total == null || total == 0 ? null : received / total);
      }
    } finally {
      await sink.close();
    }
    if (total != null && received != total) {
      throw const HttpException('incomplete_download');
    }
    return file;
  }

  /// Hands the downloaded APK to Android's package installer, which shows its
  /// own confirmation screen.
  Future<void> install(File apk) =>
      _channel.invokeMethod('installApk', {'path': apk.path});
}

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());
