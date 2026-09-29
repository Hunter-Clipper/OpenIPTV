import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/update_service.dart';

void main() {
  group('AppVersion', () {
    test('parses tags and pubspec versions', () {
      expect(AppVersion.tryParse('v0.10.46'), const AppVersion(0, 10, 46));
      expect(AppVersion.tryParse('0.10.46+1'), const AppVersion(0, 10, 46));
      expect(AppVersion.tryParse('1.2'), const AppVersion(1, 2, 0));
      expect(AppVersion.tryParse('native-libmpv-cc-v1'), isNull);
      expect(AppVersion.tryParse(null), isNull);
    });

    test('compares numerically, not as text', () {
      expect(AppVersion.tryParse('0.10.46')! > AppVersion.tryParse('0.10.9')!,
          isTrue);
      expect(AppVersion.tryParse('0.11.0')! > AppVersion.tryParse('0.10.99')!,
          isTrue);
      expect(AppVersion.tryParse('1.0.0')! > AppVersion.tryParse('0.99.99')!,
          isTrue);
      expect(AppVersion.tryParse('0.10.45')! > AppVersion.tryParse('0.10.45')!,
          isFalse);
    });
  });

  group('UpdateInfo.fromGitHubJson', () {
    test('reads version, notes and the APK asset', () {
      final info = UpdateInfo.fromGitHubJson({
        'tag_name': 'v0.10.46',
        'name': 'v0.10.46 — In-app updates',
        'body': '## What\'s new\n- Updates',
        'assets': [
          {'name': 'checksums.txt', 'browser_download_url': 'https://x/c'},
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://x/app-release.apk',
            'size': 1234,
          },
        ],
      })!;
      expect(info.version, const AppVersion(0, 10, 46));
      expect(info.title, 'v0.10.46 — In-app updates');
      expect(info.notes, startsWith('## What'));
      expect(info.apkUrl, 'https://x/app-release.apk');
      expect(info.apkSize, 1234);
    });

    test('falls back to the stable latest-APK link without an asset', () {
      final info = UpdateInfo.fromGitHubJson(
          {'tag_name': 'v0.10.46', 'name': '', 'assets': []})!;
      expect(info.apkUrl, latestApkUrl);
      expect(info.title, 'v0.10.46');
    });

    test('rejects releases without a version tag', () {
      expect(UpdateInfo.fromGitHubJson({'tag_name': 'nightly'}), isNull);
    });
  });
}
