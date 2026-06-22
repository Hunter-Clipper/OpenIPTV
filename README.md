# OpenIPTV

An open-source, ad-free, cross-platform IPTV client built in Flutter.

**Guiding principle:** *Grandma Standard* — if a non-technical user can't find their show in 3 taps, the UX has failed.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20TV%20%7C%20Desktop-lightgrey)]()

---

## What it does

- Add an IPTV source via M3U URL or Xtream credentials — that's it, no account required
- Live TV with EPG (what's on now / next)
- Movies and Series with VOD playback and continue-watching
- Multiple profiles per device (PIN-lockable, emoji avatars)
- Backup and restore via a single `.iptvprofile` file
- No ads, no telemetry, no proprietary dependencies

---

## Current status — Phase 1 in progress

We are building Phase 1: **Android phone + tablet**. All core engine work (parsers, services, database) must be complete and tested before UI work begins.

See [IPTV_BUILD_SPEC.md](./IPTV_BUILD_SPEC.md) for the full specification. See the [GitHub Issues](https://github.com/Hunter-Clipper/OpenIPTV/issues) for the task breakdown.

| Phase | Target | Status |
|---|---|---|
| 1 | Android phone + tablet | 🔨 In progress |
| 2 | Android TV | Not started |
| 3 | iOS + iPadOS | Not started |
| 4 | Apple TV | Not started |
| 5 | Windows + macOS | Not started |

---

## Developer Setup

### Requirements

| Tool | Version |
|---|---|
| Flutter | 3.22+ (stable channel) |
| Dart | 3.4+ |
| Android SDK | API 21+ (target API 34) |
| Java | 17 (for Android Gradle) |

```bash
# Verify your environment
flutter doctor -v
```

### Clone and install

```bash
git clone https://github.com/Hunter-Clipper/OpenIPTV.git
cd OpenIPTV

# Once the Flutter project is scaffolded (Issue #1):
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

`build_runner` generates Isar schema adapters and Riverpod providers. Re-run it whenever you add/change an `@collection` class or a `@riverpod` annotation.

### Run on Android

```bash
flutter run -d <device-id>

# List connected devices
flutter devices
```

### Run tests

```bash
# All tests
flutter test

# Single file
flutter test test/core/parsers/m3u_parser_test.dart

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

## Project Structure

```
lib/
├── core/
│   ├── parsers/        # M3U, XMLTV, Xtream — the data engine
│   ├── models/         # Source, Channel, Programme, Movie, Series, Episode, Profile
│   ├── services/       # SourceManager, EpgService, SearchService, PlaybackService, ProfileService
│   └── storage/        # Isar DB init, BackupManager, preferences
│
├── features/
│   ├── onboarding/     # Add Source screen (first-run flow)
│   ├── live_tv/        # Channel list + EPG panel
│   ├── movies/         # Movies grid + detail
│   ├── series/         # Series grid + detail + episode list
│   ├── player/         # Full-screen player (media_kit)
│   ├── search/         # Global search screen
│   └── settings/       # Settings, Profile, Backup screens
│
├── ui/
│   ├── phone/          # Phone-specific layouts
│   ├── tablet/         # Tablet split-view layouts
│   └── tv/             # TV leanback layouts (Phase 2)
│
├── shared/
│   ├── widgets/        # InfoTooltip and other shared widgets
│   └── theme/          # App theme (dark-first)
│
└── main.dart

test/
├── core/
│   ├── parsers/        # m3u_parser_test, xmltv_parser_test, xtream_client_test
│   ├── services/       # epg_service_test, search_service_test, backup_manager_test
│   └── models/         # profile_test
└── fixtures/           # sample.m3u, sample.xml, sample_xtream_response.json
```

---

## Architecture

**State management:** Riverpod (`flutter_riverpod`). Providers are code-generated via `riverpod_annotation` + `riverpod_generator`.

**Database:** Isar (embedded, no SQLite friction). All reads/writes are async and run off the main thread.

**Navigation:** `go_router` with deep linking. TV D-pad focus is handled at the route level.

**Video:** `media_kit` + `media_kit_video` (libmpv/VLC core). Supports HLS, MPEG-TS, RTMP, MP4, hardware decode, subtitle tracks, and TV remote input.

**Parsing:** M3U and XMLTV parsers are custom Dart (no third-party parser). M3U parsing runs in a Dart isolate for large files (100k+ channels). XMLTV is stream-parsed — the full XML is never loaded into memory.

**Platform layout selection:**
```dart
enum AppLayout { phone, tablet, tv }

class PlatformHelper {
  static AppLayout getLayout(BuildContext context) {
    if (_isTV()) return AppLayout.tv;
    final width = MediaQuery.of(context).size.width;
    return width >= 600 ? AppLayout.tablet : AppLayout.phone;
  }
}
```

---

## Key Rules

These are non-negotiable and enforced in code review.

**No analytics or telemetry** that phones home without explicit user opt-in. The app must function 100% offline except for fetching streams.

**No accounts required.** Ever.

**F-Droid compatible.** No proprietary dependencies in the main build. If a package pulls in proprietary components, find an alternative.

**User-facing errors must be plain English.** Never expose stack traces, HTTP status codes, or library error strings to the user. Map everything through the error layer (see `lib/core/services/` and the error table in the build spec).

**Parsers before UI.** The M3U, XMLTV, and Xtream parsers must be fully tested before any UI screen is merged. They are the foundation of everything.

**InfoTooltip on every non-obvious setting.** If a user might ask "what does this do?", it needs an `InfoTooltip`. See `lib/shared/widgets/info_tooltip.dart` and the complete tooltip copy in [IPTV_BUILD_SPEC.md](./IPTV_BUILD_SPEC.md).

**Performance floors** (enforced, not aspirational):
- Cold start to channel list: < 3 seconds
- Channel tap to video playing: < 2 seconds
- Search results: < 300ms post-debounce
- M3U parsing: in isolate, never blocks UI

---

## Contributing

1. Check the [open issues](https://github.com/Hunter-Clipper/OpenIPTV/issues) — start with a Phase 1 issue
2. Comment on the issue before starting work to avoid duplication
3. Branch from `main`, name your branch `feature/<issue-number>-short-description`
4. Write tests first for any parser or service work
5. Open a PR — reference the issue number in the title

**Commit style:** Short imperative subject line, no trailing period. Examples:
```
add M3U isolate parser with EXTINF tag support
fix XMLTV timezone offset parsing for negative offsets
implement InfoTooltip expand/collapse with single-open constraint
```

**PR checklist:**
- [ ] `flutter test` passes
- [ ] `flutter analyze` shows no issues
- [ ] New parsers/services have unit tests with edge-case coverage
- [ ] No hardcoded strings that should be user-facing error messages
- [ ] No new dependencies added without discussion in the issue first

---

## License

GPL-3.0 — see [LICENSE](./LICENSE).

Contributions are welcome under the same license.
