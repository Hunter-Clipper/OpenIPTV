# OpenIPTV

An open-source, ad-free, cross-platform IPTV client built in Flutter.

**Guiding principle:** *Grandma Standard* — if a non-technical user can't find their show in 3 taps, the UX has failed.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![Platform](https://img.shields.io/badge/platform-Android-lightgrey)]()
[![Latest Release](https://img.shields.io/github/v/release/Hunter-Clipper/OpenIPTV)](https://github.com/Hunter-Clipper/OpenIPTV/releases/latest)

---

## What it does

- Add an IPTV source via M3U URL or Xtream Codes credentials — no account required
- Live TV with EPG (what's on now / next), channel categories, and favorites
- Movies and Series with VOD playback, continue-watching, and per-genre browsing
- Multiple profiles per device — emoji avatars, PIN lock, Kids mode
- Dark / Light / System theme with 6 accent color choices
- Content sort toggle — provider order or A-Z, applied to both category lists and content within
- Backup and restore your full setup via a single `.iptvprofile` file
- No ads, no telemetry, no accounts

---

## Current status

| Phase | Target | Status |
|---|---|---|
| 1 | Android phone + tablet | ✅ Active development — [latest release](https://github.com/Hunter-Clipper/OpenIPTV/releases/latest) |
| 2 | Android TV | Not started |
| 3 | iOS + iPadOS | Not started |
| 4 | Apple TV | Not started |
| 5 | Windows + macOS | Not started |

---

## Screenshots

_Coming soon._

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
flutter doctor -v
```

### Clone and run

```bash
git clone https://github.com/Hunter-Clipper/OpenIPTV.git
cd OpenIPTV
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d <device-id>
```

`build_runner` generates Drift database code and Riverpod providers. Re-run it after changing any `@DriftDatabase`, `@DataClassName`, or `@riverpod` annotated class.

### Run tests

```bash
flutter test
flutter analyze
```

---

## Project Structure

```
lib/
├── core/
│   ├── models/         # Channel, Movie, Series, Episode, Profile, Source
│   ├── providers/      # theme_providers (ThemeMode, accent color, sort order)
│   ├── services/       # SourceManager, ProfileService, EpgService
│   └── storage/        # database.dart (Drift/SQLite), preferences.dart (SharedPreferences)
│
├── features/
│   ├── live_tv/        # Channel list, category grid, EPG panel
│   ├── movies/         # Movie genre grid, movie detail
│   ├── series/         # Series genre grid, series detail, episode list
│   ├── player/         # Full-screen player (media_kit)
│   ├── search/         # Global search
│   └── settings/       # Settings screen, profile overview, profile picker
│
├── shared/
│   ├── theme/          # AppTheme (dark/light/TV variants, accent swatches)
│   └── widgets/        # AppLogo, shared widgets
│
└── app.dart            # App entry, profile picker bootstrap, reactive theme
```

---

## Architecture

**State management:** Riverpod 2 (`flutter_riverpod`). Providers are code-generated via `riverpod_annotation` + `riverpod_generator`. Theme mode, accent color, and sort order are `StateProvider`s initialized from persisted preferences at startup.

**Database:** Drift (SQLite via `sqlite3_flutter_libs`). Schema is versioned with `schemaVersion` and guarded migrations (`PRAGMA table_info` checks before `addColumn`). All reads/writes are async.

**Navigation:** `go_router` with path-based deep linking.

**Video:** `media_kit` + `media_kit_video` (libmpv core). Supports HLS, MPEG-TS, MP4, hardware decode, subtitle tracks, and resume from last position.

**Parsing:** Custom Dart M3U and Xtream Codes parsers. No third-party parser dependencies.

**Responsive layout:** Grid column count is derived from screen width at runtime; TV leanback layout planned for Phase 2.

---

## Key Rules

**No analytics or telemetry.** The app functions 100% offline except for fetching streams and playlist URLs.

**No accounts required.** Ever.

**F-Droid compatible target.** No proprietary dependencies in the main build.

**User-facing errors must be plain English.** Never expose stack traces, HTTP codes, or library error strings to the user.

**Performance floors:**
- Cold start to channel list: < 3 seconds
- Channel tap to video playing: < 2 seconds
- Search results: < 300ms post-debounce

---

## Contributing

1. Check the [open issues](https://github.com/Hunter-Clipper/OpenIPTV/issues)
2. Comment before starting to avoid duplication
3. Branch from `main` — `feature/<issue-number>-short-description`
4. Open a PR referencing the issue number

**Commit style:** Short imperative subject line, no trailing period.
```
fix: channel list respects sort toggle in category view
feat: accent color picker with 6 swatches
```

**PR checklist:**
- [ ] `flutter test` passes
- [ ] `flutter analyze` shows no issues
- [ ] No hardcoded user-facing strings outside the UI layer
- [ ] No new dependencies added without discussion in the issue first

---

## License

GPL-3.0 — see [LICENSE](./LICENSE).

Contributions are welcome under the same license.
