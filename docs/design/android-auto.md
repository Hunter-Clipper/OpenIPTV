# Android Auto (and parked video)

Status: **planning** — tracks [#33](https://github.com/Hunter-Clipper/OpenIPTV/issues/33).

## Goal

Make OpenIPTV usable from the car's screen: browse your channels and
listen while driving, and — where the platform allows it — watch video
while parked (waiting to pick someone up, charging an EV).

## Two car platforms, two answers

| | Android Auto (phone projected to the car) | Android Automotive OS ("Google built-in") |
|---|---|---|
| How it runs | The phone app, shown through Google's templates | An app installed on the car itself |
| Audio while driving | ✅ media apps (browse + now playing) | ✅ media apps |
| Video | ❌ for third-party apps (Google has announced parked video for approved apps on compatible cars — check current status before relying on it) | ✅ a **parked-only** video app category |
| Distribution | Phone app; sideloaded apps need Android Auto's developer setting "Unknown sources" | **Play Store only** on production cars, after car quality review |

## Phase 1 — Audio on Android Auto (this PR)

What users get:
- OpenIPTV appears in Android Auto's media apps.
- Browse: Favorites, Recently Watched, Live TV categories → channels,
  plus Movies and Series (played as audio, resuming where you left off).
- Voice search ("Play BBC News on OpenIPTV").
- Plays the stream's **audio**, with car controls: play / pause,
  next / previous channel, and now-playing info (channel logo, current
  programme from the TV guide).
- Uses the active playlist and profile; parental locks apply and Kids
  profiles never see adult categories. Locked categories are hidden in the
  car (no PIN entry while driving).

Technical plan:
1. **Media browser service.** The app already declares a
   `MediaBrowserService` (via `audio_service`, used for the Now Playing
   notification). Either extend `NowPlayingHandler` with `getChildren` /
   `search` (audio_service supports a browse tree), or move to a Media3
   `MediaLibraryService` in Kotlin. Start with audio_service to reuse what
   exists; revisit if it limits us.
2. **Browse tree** backed by the existing providers / database queries:
   root → Live TV (Favorites, Recently Watched, categories → channels),
   Movies (Continue Watching, genres → titles) and Series (Continue
   Watching, genres → series → seasons → episodes). Artwork from logos and
   posters. Bounded lists (Android Auto limits list sizes and depth).
3. **Audio-only playback** through the existing native player without a
   video surface (disable the video track to save data / battery).
4. **Car-only guards:** no PIN dialogs, no setup or settings in the car;
   if there's no playlist or profile yet, show "Open OpenIPTV on your
   phone to get started."
5. **Manifest:** `com.google.android.gms.car.application` meta-data with an
   `automotive_app_desc.xml` declaring `media`.
6. **Plain-English car errors** ("This channel isn't available right now").

Testing: the **Desktop Head Unit (DHU)** from the Android SDK with the
phone over USB/ADB, then a real car. Users who sideload must enable
Android Auto → Settings → Developer settings → "Unknown sources"; the app
and README must explain this simply.

## Phase 2 — Parked video (future, separate decision)

Only realistic on **Android Automotive OS** cars, and only via the
**Play Store**:
- Build an automotive variant of the app (or flavour) declaring the video
  category, using Media3 ExoPlayer (already our engine).
- Listen to the car's **driving restrictions** (`CarUxRestrictionsManager`)
  and pause / hide video the instant the car isn't parked; resume as audio
  if possible.
- Pass Google's car app quality review.

Blockers to weigh before starting:
- OpenIPTV is distributed by sideloading from GitHub today; this needs a
  Play Store developer account, listing and review.
- Google Play is strict with IPTV players because of piracy concerns —
  even bring-your-own-playlist apps. Our player-only, no-content stance
  helps but approval isn't guaranteed.
- A Play-services / Play-store build conflicts with the F-Droid-friendly
  goal, so it would be a separate edition.
- Unofficial tools that force video into Android Auto exist; they bypass
  Google's restrictions, break often and can put the user's Google account
  at risk. OpenIPTV won't build on or recommend them.

## Decisions (owner, 2026-10-05)

1. **Start audio-only, for everything:** Live TV, Movies and Series are all
   browsable and play as audio in the car.
2. **Play Store edition: maybe, undecided.** Parked video stays a
   future phase; meanwhile it can be prototyped for development as below.

## Developer testing of parked video (sideloaded)

| Where | Possible? |
|---|---|
| **Android Automotive OS emulator** (AAOS x86_64 system images in the SDK) | **Yes.** The sideloaded APK installs over ADB; the parked-video category and the driving-restriction handling can be exercised by simulating gear / speed through the emulator's car data (extended controls or VHAL property injection). Flutter builds x86_64. |
| Real car with Google built-in | Generally **no** — production cars don't allow sideloading; apps come from the car's Play Store. |
| Android Auto (phone projected, incl. the Desktop Head Unit) | **No** — third-party apps only get Google's templates; there's no video surface, even for development. |

So parked video can be built and verified end-to-end in the emulator with
today's sideloaded app, as groundwork for a possible Play Store edition —
but real users could only get it in their cars through the Play Store.
Note: the emulator plus a release build is heavy for this machine's 7 GB
RAM (as with the TV emulator) — build first, then boot the emulator.

## Milestones

1. Browse tree in the DHU (Favorites, Recently Watched, categories).
2. Audio playback + car controls + now-playing info.
3. Voice search, parental / Kids filtering, car-safe error states.
4. Movies / Series browsing with resume.
5. README section on enabling it for sideloaded installs.
6. (Optional, dev-only) parked-video prototype in the Automotive emulator.
