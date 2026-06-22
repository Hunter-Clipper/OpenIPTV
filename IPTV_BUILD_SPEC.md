# IPTV App — Full Build Specification
> **For Claude Code:** This document is the single source of truth for building this app. Read it fully before writing any code. Follow the phases in order. Do not skip ahead.

---

## Project Overview

An open-source, ad-free, cross-platform IPTV client built in Flutter. The guiding principle is **"Grandma Standard"** — if a non-technical user can't find their show in 3 taps, the UX has failed. Every feature must earn its place. No bloat, no dark patterns, no telemetry, no accounts required.

**License:** GPL-3.0  
**Distribution:** Google Play, F-Droid (no proprietary deps), Apple App Store, GitHub Releases  
**Primary target:** Android phone + tablet first, then Android TV, then iOS/iPadOS, Apple TV, Windows, macOS.

---

## Tech Stack

| Layer | Choice | Notes |
|---|---|---|
| Framework | Flutter (Dart) | Single codebase for all platforms |
| Video Player | `media_kit` + `media_kit_video` | libmpv/VLC core. HLS, MPEG-TS, RTMP, MP4, subtitles, hardware decode, TV remote support |
| M3U Parsing | Custom Dart (no lib) | Full control, handles M3U and M3U+ |
| XMLTV Parsing | Custom Dart XML parser | `xml` package from pub.dev |
| Xtream API | Dart `http` package | Direct REST calls |
| Fuzzy Search | Custom Dart scorer | ~30-line trigram/substring scorer — no library dependency |
| State Management | Riverpod (`flutter_riverpod`) | Clean, testable, scalable |
| Local Database | `drift` + `drift_flutter` | SQLite-based ORM; F-Droid compatible (system library, no prebuilt binaries) |
| Navigation | `go_router` | Deep linking, TV D-pad focus support |
| Image Cache | `cached_network_image` | Channel logos, VOD posters |
| Encryption | `encrypt` package (AES-256) | Profile backup encryption when PIN is set |
| Archive | `archive` package | `.iptvprofile` backup file (ZIP-based) |
| Background Audio | `audio_service` | iOS/Android background audio for live TV |

---

## Project Structure

```
lib/
├── core/
│   ├── parsers/
│   │   ├── m3u_parser.dart          # Parses M3U and M3U+ into Channel/VOD models
│   │   ├── xmltv_parser.dart        # Parses XMLTV EPG feeds into Programme models
│   │   └── xtream_client.dart       # Xtream API REST client
│   ├── models/
│   │   ├── source.dart              # A user-added source (type, URL, credentials)
│   │   ├── channel.dart             # Live TV channel
│   │   ├── programme.dart           # EPG programme entry
│   │   ├── movie.dart               # VOD movie
│   │   ├── series.dart              # VOD series
│   │   ├── episode.dart             # Series episode
│   │   └── profile.dart             # User profile
│   ├── services/
│   │   ├── source_manager.dart      # Add/remove/refresh sources
│   │   ├── epg_service.dart         # EPG loading, matching, 5-day cache
│   │   ├── search_service.dart      # Unified search across all content types
│   │   ├── playback_service.dart    # Stream URL resolution, track selection
│   │   └── profile_service.dart     # Profile CRUD, active profile switching
│   └── storage/
│       ├── database.dart            # Drift DB init, table definitions, and migrations
│       ├── backup_manager.dart      # Export/import .iptvprofile files
│       └── preferences.dart         # App-level prefs (not profile-specific)
│
├── features/
│   ├── onboarding/
│   │   └── add_source_screen.dart   # First-run and add-source flow
│   ├── live_tv/
│   │   ├── channel_list_screen.dart
│   │   └── epg_panel.dart           # Slide-up EPG strip for a channel
│   ├── movies/
│   │   ├── movies_screen.dart
│   │   └── movie_detail_screen.dart
│   ├── series/
│   │   ├── series_screen.dart
│   │   ├── series_detail_screen.dart
│   │   └── episode_list_screen.dart
│   ├── player/
│   │   ├── player_screen.dart       # Full-screen player
│   │   └── player_controls.dart     # Overlay controls, D-pad aware
│   ├── search/
│   │   └── search_screen.dart       # Global search with grouped results
│   └── settings/
│       ├── settings_screen.dart
│       ├── profile_screen.dart      # Manage profiles, PIN, switch
│       └── backup_screen.dart       # Backup and restore UI
│
├── ui/
│   ├── phone/                       # Phone-specific layouts
│   ├── tablet/                      # Tablet split-view layouts
│   └── tv/                          # TV leanback layouts (focus rings, large cards)
│
├── shared/
│   ├── widgets/
│   │   └── info_tooltip.dart        # The (ℹ️) tooltip widget — used everywhere
│   └── theme/
│       └── app_theme.dart           # Dark-first theme, TV-safe colors
│
└── main.dart
```

---

## Data Models

### Source
```dart
enum SourceType { m3u, xtream }

class Source {
  String id;
  String nickname;          // User-facing name, e.g. "Home Server"
  SourceType type;
  String? m3uUrl;           // For M3U/M3U+
  String? xtreamHost;       // For Xtream: base URL
  String? xtreamUsername;
  String? xtreamPassword;
  String? epgUrl;           // Optional separate XMLTV URL
  DateTime? lastRefreshed;
}
```

### Channel
```dart
class Channel {
  String id;
  String sourceId;
  String name;
  String? logoUrl;
  String streamUrl;
  String? groupTitle;       // Category from M3U group-title or Xtream category
  String? tvgId;            // For EPG matching
  String? tvgName;          // Fallback for EPG matching
  bool isFavorite;
  int sortOrder;
}
```

### Programme (EPG)
```dart
class Programme {
  String channelId;         // Matched to Channel.tvgId
  DateTime start;
  DateTime end;
  String title;
  String? description;
  String? category;
  String? episodeNum;
}
```

### Movie
```dart
class Movie {
  String id;
  String sourceId;
  String title;
  String? posterUrl;
  String streamUrl;
  String? genre;
  String? year;
  String? rating;
  String? description;
  Duration? watchedDuration;   // For Continue Watching
  Duration? totalDuration;
}
```

### Series + Episode
```dart
class Series {
  String id;
  String sourceId;
  String title;
  String? posterUrl;
  String? genre;
  String? year;
  String? description;
}

class Episode {
  String id;
  String seriesId;
  String sourceId;
  int season;
  int episode;
  String title;
  String streamUrl;
  String? stillUrl;
  Duration? watchedDuration;
  Duration? totalDuration;
}
```

### Profile
```dart
class Profile {
  String id;
  String name;
  String avatarEmoji;       // e.g. "👨", "👩", "🧒" — no photo complexity
  String? pinHash;          // SHA-256 of PIN, null if no PIN set
  List<String> sourceIds;
  List<String> favoriteChannelIds;
  List<String> favoriteMovieIds;
  List<String> favoriteSeriesIds;
  String defaultCategory;   // Which category tab to open on launch
  String channelSortOrder;  // "provider", "az", "custom"
  String defaultSubtitleLang;
  String defaultAudioLang;
  Map<String, int> customChannelOrder;  // channelId → sort position
  Map<String, String> epgOverrides;    // channelId → manual tvg-id override
  List<String> hiddenCategories;
  DateTime createdAt;
  DateTime updatedAt;
}
```

---

## Source Auto-Detection Logic

When a user pastes something into the "Add Source" field, auto-detect silently:

```
Input received
│
├── Has host + username + password fields filled?
│   └── YES → Try Xtream API: GET /player_api.php?action=get_live_categories
│             ├── 200 OK with JSON → SourceType.xtream ✅
│             └── Fail → Show error "Couldn't connect with these credentials"
│
└── Has a URL only?
    ├── Fetch URL (HEAD first, then GET if needed)
    ├── Content-Type or body starts with "#EXTM3U" → SourceType.m3u ✅
    └── Fail → Show error "Couldn't read this URL"
```

**M3U vs M3U+:** No meaningful distinction needed internally — parse as M3U, handle extended tags (`#EXTINF`, `#EXTVLCOPT`, etc.) automatically.

**EPG auto-detection:**
- If Xtream source: check `get_epg` endpoint automatically
- If M3U: look for `url-tvg` or `x-tvg-url` in the `#EXTM3U` header line
- Allow user to manually add/override EPG URL at any time

---

## Parsers

### M3U Parser (`m3u_parser.dart`)

Must handle:
- `#EXTM3U` header (extract `url-tvg`, `x-tvg-url`, `tvg-shift`)
- `#EXTINF` lines: duration, `tvg-id`, `tvg-name`, `tvg-logo`, `group-title`, channel name
- Stream URL on the line immediately after `#EXTINF`
- VOD detection: if `group-title` contains "VOD", "Movies", "Films", "Series", "Shows" (case-insensitive) → route to VOD models
- Series detection: if group-title contains "Series" or "Shows", or name contains `S[0-9]+E[0-9]+` pattern
- Large files (100k+ channels): parse in isolate to avoid UI jank

### XMLTV Parser (`xmltv_parser.dart`)

Must handle:
- `<channel>` elements: `id`, `display-name`, `icon`
- `<programme>` elements: `start`, `stop`, `channel`, `title`, `desc`, `category`, `episode-num`
- Timezone offsets in timestamps
- Stream-parse large files (don't load entire XML into memory)
- Cache parsed data in drift with 5-day window — discard programmes older than now, keep up to 5 days ahead
- EPG channel → app channel matching priority:
  1. Exact `tvg-id` match
  2. Exact `tvg-name` match
  3. Case-insensitive name fuzzy match (custom scorer — see Search Service)

### Xtream Client (`xtream_client.dart`)

Base URL: `http(s)://HOST/player_api.php`

Endpoints to implement:
```
GET ?username=X&password=Y&action=get_live_categories
GET ?username=X&password=Y&action=get_live_streams&category_id=Z
GET ?username=X&password=Y&action=get_vod_categories
GET ?username=X&password=Y&action=get_vod_streams&category_id=Z
GET ?username=X&password=Y&action=get_series_categories
GET ?username=X&password=Y&action=get_series&category_id=Z
GET ?username=X&password=Y&action=get_series_info&series_id=Z
GET ?username=X&password=Y&action=get_short_epg&stream_id=Z&limit=5  (5-day EPG)
GET ?username=X&password=Y&action=get_vod_info&vod_id=Z

Stream URL format: HOST/STREAM_TYPE/USERNAME/PASSWORD/STREAM_ID.EXTENSION
```

---

## EPG Service

- On source add/refresh: fetch XMLTV, parse, store in drift
- Match channels to programmes by tvg-id/name (see parser above)
- Keep only programmes from `now` to `now + 5 days`
- Refresh EPG: every 12 hours in background, or on manual pull-to-refresh
- Expose:
  - `getCurrentProgramme(channelId)` → Programme?
  - `getNextProgramme(channelId)` → Programme?
  - `getProgrammesForChannel(channelId, date)` → List\<Programme\>
  - `searchProgrammes(query)` → List\<Programme\> (for global search)

---

## Search Service

Single search bar. One query searches:
1. Channel names (fuzzy)
2. EPG programme titles + descriptions (fuzzy, within 5-day window)
3. Movie titles (fuzzy)
4. Series titles (fuzzy)

### Fuzzy Scorer

No library — custom two-pass Dart scorer in `lib/core/services/search_service.dart`:

```dart
// Pass 1: query is a substring of title (case-insensitive) → score 1.0
// Pass 2: all query chars appear in order in title → score 0.5
// Otherwise: excluded from results
```

This handles the common IPTV case ("bbc" → "BBC One", "BBC Two") with zero dependencies and sub-millisecond performance at 100k entries.

Results returned as:
```dart
class SearchResults {
  List<Channel> channels;
  List<Programme> programmes;   // Include parent channel info
  List<Movie> movies;
  List<Series> series;
}
```

Display grouped in results screen with headers: "Live Channels", "On TV", "Movies", "Series". Empty groups are hidden.

Minimum query length: 2 characters. Debounce: 300ms.

---

## Player

Use `media_kit` + `media_kit_video`.

### Stream Type Detection
```
Stream URL
├── Contains .m3u8 or stream type hint "hls" → HLS via media_kit
├── Contains .ts or type hint "mpeg-ts"       → MPEG-TS via media_kit  
├── Contains .mp4, .mkv, .avi                 → Progressive via media_kit
└── Default                                   → Let media_kit auto-detect
```

### Player Controls (Phone/Tablet)
- Tap screen → show/hide overlay (auto-hide after 4 seconds)
- Overlay shows: channel/title name, back button, favourite toggle, EPG button
- Live TV: show "LIVE" badge, current programme name + time bar
- VOD: progress bar, seek, current time / total time
- Swipe up on player → EPG strip for this channel (live TV only)
- Double-tap left/right → seek ±10 seconds (VOD only)

### Player Controls (TV / D-pad)
- OK/Select → play/pause
- Left/Right → seek ±10s (VOD) or previous/next channel (live)
- Up/Down → volume
- Back → exit player
- Menu → show EPG or info overlay
- Focus ring always visible on interactive elements

### Subtitle & Audio Track Selection
- If stream has multiple audio tracks → show audio selector in player overlay
- If stream has subtitle tracks → show subtitle selector
- Remember last-used audio language and subtitle language per profile

### Continue Watching
- Save position every 10 seconds for VOD content
- On re-open: show "Resume from 43:21" or "Start over"
- Mark as watched when >90% complete, stop saving position

---

## UI Layout

### Navigation (Phone/Tablet)
Bottom navigation bar — 4 items only:
```
[ 📺 Live TV ]  [ 🎬 Movies ]  [ 📺 Series ]  [ 🔍 Search ]
```
Settings accessible via gear icon in top-right of any screen. No hamburger menus.

### Navigation (TV)
Top navigation rail (horizontal), D-pad navigable:
```
[ Live TV ]  [ Movies ]  [ Series ]  [ Search ]  [ Settings ]
```

### Live TV Screen
```
┌─────────────────────────────────────────────────┐
│  [Category tabs — horizontally scrollable]       │
│  All  News  Sports  Entertainment  Kids  ...     │
├─────────────────────────────────────────────────┤
│  [Logo]  BBC One          Now: Eastenders        │
│                           Next: The One Show     │
├─────────────────────────────────────────────────┤
│  [Logo]  ITV              Now: Coronation St     │
│                           Next: News at Ten      │
├─────────────────────────────────────────────────┤
│  ...                                             │
└─────────────────────────────────────────────────┘
```
- Pull-to-refresh triggers source + EPG refresh
- Star icon on each row for quick favourite toggle
- Tap row → full-screen player

### Movies Screen
Poster grid (2 columns phone, 4 columns tablet, 5 columns TV).
Genre filter chips horizontally scrollable at top.
Tap poster → Movie detail screen (description, year, genre, rating, Play button).

### Series Screen
Same poster grid layout.
Tap → Series detail (description, season picker, episode list).
Episode rows show: episode number, title, duration, watched progress bar.

### Player Screen (Full-screen, dark)
```
┌────────────────────────────────────────┐
│                                        │
│           [VIDEO PLAYING]              │
│                                        │
│  ← BBC One                   ⭐  [EPG]│
│  ████████████░░░░░  LIVE               │
│  Now: Eastenders   21:00 – 22:00       │
└────────────────────────────────────────┘
```

### Settings Screen
Clean list. No nested sub-menus more than 1 level deep.
```
Settings
├── Profiles          → Profile list, add/switch/delete, PIN setup
├── Sources           → List of added sources, add new, refresh, remove
├── Backup & Restore  → Export/import .iptvprofile
├── Playback          → Default subtitle lang, audio lang, player behaviour
├── Appearance        → Theme (dark/light/system), channel list density
└── About             → Version, GitHub link, licenses
```

---

## Profile System

### Multiple Profiles
- App can have 1–10 profiles
- First-run creates a default profile (no PIN, no avatar, name = "Me")
- Switching profiles: tap profile avatar in top-right → profile picker sheet → tap to switch
- Each profile is fully independent: sources, favourites, settings, watch history

### PIN Lock
- 4-digit numeric PIN
- If set: required to switch into this profile and to export its backup
- Stored as SHA-256 hash, never plaintext
- "Forgot PIN" → delete profile or restore from backup (documented clearly)

### Profile Avatars
Emoji-only picker (no photos). Offer ~20 options: 👨 👩 🧒 👦 👧 🧑 👴 👵 🎭 🌟 🎮 🎬 📺 🎵 🏠 ⚽ 🎸 🐱 🐶 🦄

---

## Backup & Restore

### File Format: `.iptvprofile`
A renamed ZIP archive containing:
```
myprofile.iptvprofile  (ZIP)
├── manifest.json          # Schema version, app version, created timestamp
├── profile.json           # All profile settings, favourites, sort orders, watch history
├── sources.json           # Source URLs and credentials
└── epg_mappings.json      # Custom EPG channel overrides
```

If the profile has a PIN set, `sources.json` is AES-256 encrypted. All other files are plain JSON (readable by anyone with a zip tool — document this openly).

### manifest.json structure
```json
{
  "schema_version": 1,
  "app_version": "1.0.0",
  "created_at": "2025-06-20T12:00:00Z",
  "profile_name": "Dad",
  "encrypted": false
}
```

### Backup Flow
```
Settings → Backup & Restore → Back Up Profile
→ Creates .iptvprofile file
→ Opens OS share sheet (user sends to Drive, iCloud, email, WhatsApp, etc.)
→ OR: Save to Downloads folder directly
```

### Restore Flow
```
Settings → Backup & Restore → Restore from Backup
→ OS file picker (user selects .iptvprofile)
→ If encrypted: prompt for PIN
→ Preview: "This will restore profile 'Dad' — created June 20, 2025. Restore?"
→ Confirm → restore
→ "Done. Your channels and favourites are back."
```

### Version Migration
- Always check `schema_version` in manifest on restore
- If app is older than the backup schema: show warning "This backup was made with a newer version of the app. Some settings may not restore correctly."
- Build a migration function `migrateProfile(int fromVersion, int toVersion, Map data)` from day one — add to it as schema evolves

---

## The (ℹ️) Tooltip System

**Every** setting, toggle, or field that isn't self-evident must have an (ℹ️) icon next to its label. This is non-negotiable.

### Widget: `InfoTooltip`
```dart
// Usage example
Row(
  children: [
    Text("EPG Source URL"),
    InfoTooltip(
      title: "EPG Source URL",
      body: "A link to a TV guide that shows what's on and when. "
            "This fills in programme names and times next to your channels. "
            "Without it, you'll still get channels — just no guide info. "
            "Your IPTV provider usually gives you this link. "
            "It often ends in .xml or .xmltv.",
      tip: "Most providers include EPG automatically — only add this if your guide is empty.",
    ),
  ],
)
```

Tapping (ℹ️) expands an inline card below the row — no new screen, no dialog. Tap again to collapse. One can be open at a time.

### (ℹ️) Entries — Complete List

Write these exactly as specified. Plain English. No jargon without explanation.

**Add Source — URL field**
> A link to your channel list, provided by your IPTV service. Paste it exactly as given. It usually starts with `http://` or `https://` and ends in `.m3u` or `.m3u8`. If your provider gave you a username and password instead, use the Xtream login option below.

**Add Source — Xtream login (host/user/pass)**
> Some IPTV services use a login system called Xtream. Enter the server address, your username, and password exactly as your provider gave them to you. The app will connect and download your channel list automatically.

**EPG Source URL**
> A link to a TV guide showing what's on and when. Fills in programme names, times, and descriptions next to your channels. Your IPTV provider usually supplies this — it often ends in `.xml` or `.xmltv`. If your guide is already showing programme info, you don't need to add anything here.

**Channel Sort Order**
> Controls the order channels appear in your list. "Provider order" uses the order your service arranged them. "A–Z" sorts alphabetically. "Custom" lets you drag channels into any order you like. Your favourites always appear at the top regardless of this setting.

**Profile PIN**
> A 4-digit code that locks this profile. Anyone wanting to switch to this profile or change its settings will need to enter it first. Also encrypts your passwords if you export a backup. Great for a Kids profile. If you forget it, you can restore from a backup or delete and recreate the profile.

**Profile Avatar**
> A small picture that represents this profile on the switcher screen. Pick any emoji — it's just to make profiles easy to tell apart at a glance.

**Backup & Restore**
> Saves everything about your profile — channels, favourites, settings, and what you've been watching — into a single file. Use it to move to a new phone, share your setup, or just keep a safety copy. The file is called `.iptvprofile` and works like a zip file if you ever want to look inside it.

**Default Category on Launch**
> Which channel category the app opens to when you start it. Set this to your most-watched category so you get there instantly. You can always switch categories once you're in the app.

**Default Subtitle Language**
> If a stream has subtitles available, the app will automatically turn on this language. Leave it blank to keep subtitles off by default. You can always change it manually inside the player.

**Default Audio Language**
> If a stream has multiple audio tracks (e.g. English and Spanish), the app will automatically choose this language. Useful if you prefer a dubbed version of content.

**Continue Watching**
> Remembers where you left off in movies and series, and shows a "Resume" option next time. The app considers something "watched" once you've seen 90% of it and stops tracking it. Stored only on your device and included in your backup.

**Hidden Categories**
> Categories in your channel list that you've chosen not to see. They still exist on your provider's service — they're just hidden from your view. Useful for removing categories you never use (like a language you don't watch). You can unhide them at any time.

**EPG Time Window**
> How many days of TV guide information the app keeps. Set to 5 days maximum. More days means slightly more storage used on your device, but you can browse further ahead to plan your watching.

**Custom EPG Mapping**
> Normally the app matches your channels to the TV guide automatically by name. If a channel's guide isn't showing up correctly, you can manually tell the app which guide entry to use for it. Only needed if a channel's guide info is wrong or missing.

**Source Nickname**
> A friendly name for this source, shown in your settings. Doesn't affect anything — just makes it easier to tell apart if you have more than one source added. Example: "Home Server" or "Holiday Package".

---

## Platform Adaptation

Use `LayoutBuilder` and a `PlatformHelper` class to select layout at runtime:

```dart
enum AppLayout { phone, tablet, tv }

class PlatformHelper {
  static AppLayout getLayout(BuildContext context) {
    if (_isTV()) return AppLayout.tv;
    final width = MediaQuery.of(context).size.width;
    return width >= 600 ? AppLayout.tablet : AppLayout.phone;
  }
  
  static bool _isTV() {
    // Check android TV / fire TV / apple TV
  }
}
```

TV layout differences:
- No bottom navigation bar — use top horizontal nav rail
- All cards larger (TV is viewed from distance)
- Focus rings always visible (never hidden)
- No hover states — everything is D-pad navigable
- Player controls designed for remote (OK, directional, back, menu buttons)
- No text input where avoidable — search uses voice on TV if available

---

## Performance Requirements

- **App cold start to channel list:** < 3 seconds (sources already added)
- **Channel tap to video playing:** < 2 seconds on a good connection
- **Search results:** < 300ms after debounce
- **M3U parsing:** run in Dart isolate — must not block UI thread
- **XMLTV parsing:** stream-parse, never load full file into memory
- **EPG refresh:** background isolate, user never sees a loading spinner for EPG
- **Image loading:** `cached_network_image` with memory + disk cache, placeholder shimmer
- **Isar DB:** all reads/writes async, never on main thread

---

## Error Handling — User-Facing Messages

Never show technical errors to users. Map all errors to plain English:

| Technical Error | User-Facing Message |
|---|---|
| HTTP 401/403 | "Your username or password doesn't seem right. Check with your provider." |
| HTTP timeout | "Couldn't reach this server. Check your internet connection and try again." |
| M3U parse fail | "This link doesn't look like a valid channel list. Check the URL with your provider." |
| Stream playback fail | "This channel isn't available right now. Try again or pick a different one." |
| EPG fetch fail | "Couldn't load the TV guide. Your channels still work — guide info will retry automatically." |
| File not found (restore) | "Couldn't open this backup file. Make sure it's a valid .iptvprofile file." |
| Wrong PIN (restore) | "That PIN doesn't match this backup. Try again." |

All errors show a retry button where retrying makes sense.

---

## Build Phases

### Phase 1 — Android Phone + Tablet ✅ BUILD THIS FIRST

**Goal:** Fully working app on Android, all core features.

- [ ] Project scaffold: Flutter, all dependencies in pubspec.yaml
- [ ] Isar database schema + init
- [ ] M3U parser (isolate-based, handles M3U and M3U+)
- [ ] XMLTV parser (stream-based, 5-day window)
- [ ] Xtream API client (all required endpoints)
- [ ] Source auto-detection logic
- [ ] Profile model + CRUD + active profile state
- [ ] Onboarding / Add Source screen with auto-detection
- [ ] Live TV: channel list, categories, favourites, EPG now/next
- [ ] Movies: poster grid, genre filter, detail screen
- [ ] Series: poster grid, series detail, season/episode list
- [ ] Global search (channels + EPG + movies + series)
- [ ] Full-screen player (media_kit, live + VOD, controls overlay)
- [ ] EPG slide-up panel in player
- [ ] Continue Watching (save/resume position)
- [ ] Settings screen (all sections)
- [ ] Profile screen (create, switch, PIN, avatar)
- [ ] Backup & Restore (.iptvprofile export/import)
- [ ] All (ℹ️) tooltips implemented on every relevant field
- [ ] Error messages (user-facing, see table above)
- [ ] Phone layout
- [ ] Tablet layout (split-view where appropriate)
- [ ] Dark theme (default), light theme, system-follow option

### Phase 2 — Android TV

- [ ] TV layout skin (`ui/tv/`)
- [ ] D-pad navigation baked in throughout app
- [ ] TV-sized cards, leanback-style horizontal browsing
- [ ] Remote-friendly player controls
- [ ] Focus ring system
- [ ] No keyboard-reliant flows

### Phase 3 — iOS + iPadOS

- [ ] Port (most things work already)
- [ ] Background audio (`audio_service`)
- [ ] AirPlay support (media_kit AVKit backend)
- [ ] iOS-specific file picker for backup restore
- [ ] App Store metadata + privacy policy

### Phase 4 — Apple TV

- [ ] Enable Flutter tvOS target
- [ ] Siri Remote swipe gesture handling
- [ ] TV layout reuse from Phase 2

### Phase 5 — Desktop (Windows + macOS)

- [ ] libmpv already works via media_kit on desktop
- [ ] Window sizing and responsive layout at large sizes
- [ ] Native file picker for backup
- [ ] Optional: system tray mini-player

---

## Open Source Requirements

- **No analytics, no telemetry, no crash reporting that phones home** without explicit opt-in
- **No ads, ever** — enforced by GPL-3.0
- **No required accounts** — the app works fully offline except for fetching streams
- **F-Droid compatible** — no proprietary dependencies in the main build. If a dependency has a proprietary component, find an alternative.
- **`/docs` folder in repo:**
  - `getting-started.md` — Add your first source in 2 minutes
  - `backup-restore.md` — Step by step with screenshots
  - `profiles.md` — Setting up profiles for a household
  - `epg-setup.md` — What EPG is and how to connect one
  - `troubleshooting.md` — Stream won't play? Start here
  - `contributing.md` — How to contribute code, report bugs, request features

---

## pubspec.yaml Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Player
  media_kit: ^1.1.10
  media_kit_video: ^1.2.4
  media_kit_libs_video: ^1.0.4        # Platform-specific codecs

  # State
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Database
  drift: ^2.18.0
  drift_flutter: ^0.2.0           # SQLite setup on all platforms (no prebuilt binaries)
  path_provider: ^2.1.3

  # Navigation
  go_router: ^13.2.0

  # Networking
  http: ^1.2.1

  # XML
  xml: ^6.5.0

  # Images
  cached_network_image: ^3.3.1

  # Encryption
  encrypt: ^5.0.3
  crypto: ^3.0.3               # SHA-256 for PIN hashing

  # Archive (backup files)
  archive: ^3.6.1

  # Background audio
  audio_service: ^0.18.12

  # File operations
  file_picker: ^8.0.3
  share_plus: ^9.0.0
  path: ^1.9.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.18.0
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.9
  flutter_lints: ^4.0.0
```

---

## Testing Requirements

Write unit tests for all parsers and services before moving to UI:

```
test/
├── core/
│   ├── parsers/
│   │   ├── m3u_parser_test.dart      # Test edge cases: empty file, missing tags, huge files
│   │   ├── xmltv_parser_test.dart    # Test timezone handling, missing elements
│   │   └── xtream_client_test.dart   # Test with mock HTTP responses
│   ├── services/
│   │   ├── epg_service_test.dart     # Test matching logic, 5-day window
│   │   ├── search_service_test.dart  # Test fuzzy matching, grouping
│   │   └── backup_manager_test.dart  # Test export/import round-trip
│   └── models/
│       └── profile_test.dart
```

Include fixture files in `test/fixtures/`:
- `sample.m3u` — 50 channels, mix of live + VOD
- `sample.xml` — XMLTV with 3 days of data
- `sample_xtream_response.json` — mock Xtream API responses

---

## Start Here

**First task for Claude Code:**

1. Create the Flutter project: `flutter create --org com.openiptv --project-name open_iptv .`
2. Set up `pubspec.yaml` with all dependencies above
3. Implement the data models (all in `lib/core/models/`)
4. Implement the M3U parser with isolate support and unit tests
5. Implement the XMLTV parser with stream-parsing and unit tests
6. Implement the Xtream client with mock-testable HTTP layer and unit tests
7. Then move to UI, starting with the onboarding / add source screen

Do not build UI before the core engine is tested and solid. The parsers are the foundation of everything.
