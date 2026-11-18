# Dependency review

How to check and update OpenIPTV's dependencies, what the last review
(2026-11-17/18, tracked in #191) changed, and what is deliberately held back.
The exact versions in use are in `pubspec.lock`, the README tables and
[THIRD_PARTY_NATIVE.md](THIRD_PARTY_NATIVE.md).

## How to run a review

1. **Dart packages:** `flutter pub outdated`, then `flutter pub upgrade` for
   in-range updates. "Resolvable" is what can actually be taken.
2. **Android native versions:** compare `android/app/build.gradle.kts`
   (Media3, MediaRouter, Cast, WireGuard tunnel, desugar_jdk_libs, NDK) with
   Maven metadata (`dl.google.com/android/maven2/...`, `repo1.maven.org/...`),
   and the OpenVPN source pins in `android/openvpn-deps.sh` with upstream tags.
3. **Flutter itself:** `flutter upgrade --verify-only`. Flutter dictates the
   minimum Android Gradle plugin, Gradle and Kotlin versions (see
   `packages/flutter_tools/gradle/.../DependencyVersionChecker.kt` in the SDK).
4. **One library per commit**, low risk first. Majors that touch the database
   or encryption go in their own PR. Open one GitHub issue per risky item with
   a plan, test plan and acceptance criteria.

## Must-do checks for every dependency PR

- `flutter analyze` (no errors) and the full test suite (`flutter test -j 1`).
- Update the README developer-setup and "Main libraries" tables and the
  changelog ("Under the hood").
- `tools/check-apk-sqlcipher.sh build/app/outputs/flutter-apk/app-release.apk`
  passes (libsqlcipher.so for every ABI). The `hooks:` block in `pubspec.yaml`
  (`sqlite3: source: sqlcipher`) must stay; without it the APK ships plain
  SQLite and cannot open the encrypted database.
- For anything touching the database, secure storage or the Android
  toolchain: an **upgrade test over the previous build** on an emulator or
  throwaway device — install the old build, let it create an encrypted
  database with data, install the new build over it, and check the log shows
  `[OTV-db] opened (encrypted)` with the same row counts. Never use a real
  user's phone first.
- The build number (`+N` in `pubspec.yaml`) must be higher than any build
  already installed on a test device (Android refuses downgrades).
- Sign with the release key only (see the release process); verify with
  `apksigner verify --print-certs`.

## Testing the built-in VPN (OpenVPN sources, NDK, Mbed TLS)

Use a **throwaway OpenVPN server**, never a personal VPN profile:

1. `apt install openvpn easy-rsa`; make an EC PKI with easy-rsa, a `tls-crypt`
   key, and a server on `10.88.66.0/24` with no `redirect-gateway`. Check the
   login with an `auth-user-pass-verify` script (`via-env`).
2. Build a client `.ovpn` with the certificates inline and the host's LAN
   address as `remote`; push it to the device (Downloads on a phone, the app's
   external files folder on a TV).
3. Settings → Advanced → Power User Tools → VPN → Import. Check: connect (the
   server log shows the handshake and the data channel cipher), traffic flows
   (ping the tunnel address from the host, including a burst of large
   packets), disconnect, reconnect, **Whole device** mode (the tunnel's UID
   ranges must skip Android Auto's app), and **Connect when OpenIPTV opens**
   after a force-stop.
4. Remove the profile in the app, delete the pushed file, stop the server and
   remove the packages.

## What the 2026-11 review changed

| Area | Change |
|---|---|
| Dart packages | Riverpod 3, go_router 18, flutter_local_notifications 23, cached_network_image 4, flutter_secure_storage 11, file_picker 13, share_plus 13, package_info_plus 10, archive 4, workmanager 0.10, permission_handler 13, xml 7, Drift 2.35, sqlite3 3.5 with its bundled SQLCipher (replacing the end-of-life `sqlcipher_flutter_libs`) |
| Flutter | 3.44.3 → 3.50.0 (Dart 3.14) |
| Android build | AGP 8.7 → 9.3.1, Gradle → 9.5.0, Kotlin → 2.4.21 with Android's built-in Kotlin, compile SDK 37, NDK 28.2 → 29 |
| UI toolkit | `package:flutter/material.dart` → `package:material_ui` (and `cupertino_ui`) |
| Native, VPN | Mbed TLS 3.6.4 → 3.6.8, Asio 1.38.2 → 1.39.0, {fmt} 11.1.4 → 12.2.1, LZ4 1.10.0 → 1.11.1, xxHash 0.8.3 → 0.8.4 |
| Native, other | Google Cast framework 22.3.1 → 23.0.0 (needs Kotlin 2.4), desugar_jdk_libs 2.1.4 → 2.1.5 |
| Safety | The app refuses to open/reset a database when the bundled SQLite has no SQLCipher; a reset keeps the old key; `tools/check-apk-sqlcipher.sh` is a release gate |

## Held back on purpose (re-check each review)

| Item | Why |
|---|---|
| OpenVPN 3 core | Pinned to a tested `master` commit. Its newest tag (`release/3.11.8`) is on an older release line (Asio 1.24 patch set), so moving to it would be a downgrade. `master` itself moves slowly; its own Asio port is still 1.38.2. |
| Asio patch 0003 | OpenVPN's Windows-only error-message patch no longer applies to Asio 1.39. `openvpn-deps.sh` skips that one patch (Android never compiles it) and still stops if any other patch fails. |
| Mbed TLS 4.x | A major version with API changes; OpenVPN 3 support for it is not assumed. Stay on the 3.6 LTS line unless OpenVPN 3 documents 4.x support. |
| intl | Pinned by the Flutter SDK (`flutter_localizations`). |
| sqlite3 3.9 | Held by the current Drift / drift_dev constraint. |
| xml 7.1, build_runner 2.17, cached_network_image 4.0.7 | Held by the resolver / dependent packages (check `flutter pub outdated`). |
| `workmanager_android` Kotlin warning | Flutter's build still warns that this third-party plugin applies the Kotlin Gradle plugin. It is already at its latest version (0.10.9) and handles both modes; re-check for a release that drops the warning. |
| gen-l10n deprecation | `flutter gen-l10n` (3.50) still emits `GlobalMaterialLocalizations` / `GlobalCupertinoLocalizations`; `lib/l10n/gen` is excluded from analysis until the generator is updated. |

## Still being observed

The finished-refresh **notification** (flutter_local_notifications 23) only
fires from the background Auto-Refresh job. Report a missing or malformed
notification as a new issue.

## Environment notes

- Android builds need `ANDROID_HOME` exported and: SDK platform 37 and
  build-tools 35, NDK `29.0.14206865`, AGP 9.3.1 / Gradle 9.5.0 (the wrapper),
  Java 17. The SDK folder may be root-owned, so installing needs `sudo
  sdkmanager ...`.
- The first build after clearing `android/.ovpn-deps` re-fetches the OpenVPN
  sources from GitHub and compiles them (about 6–10 minutes).
- Emulator testing needs `/dev/kvm` access on the development machine.
