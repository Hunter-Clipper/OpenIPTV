# iOS + iPadOS port (issue #25)

Status: planning. Branch `feature/25-ios-port`.

## Decisions (owner, 2026-10-06)

- **Video: Apple's native player (AVPlayer) first.** Most streams the app is
  used with are HLS, which AVPlayer plays natively, with AirPlay and
  Picture-in-Picture for free. If too many streams fail, we pivot to a
  VLC/mpv-based player later; the Dart side shouldn't need to change.
- **No paid Apple Developer account for now.** Testing uses a free Apple ID
  in Xcode on the owner's test Mac: builds install over USB and expire after
  7 days (re-run to refresh). TestFlight and the App Store wait until the
  $99/year program is worth it.
- Phones and tablets only. Apple TV is phase 4 (#26).

## How a test build gets onto the iPhone

1. On the Mac: install Xcode (App Store) and Flutter; open Xcode once and add
   the Apple ID under Settings → Accounts.
2. Clone the repo and check out this branch, then `flutter pub get` and
   `cd ios && pod install`.
3. In `ios/Runner.xcworkspace`, Runner target → Signing & Capabilities: tick
   "Automatically manage signing" and pick the Apple ID's *Personal Team*.
   The bundle ID `com.openiptv.app` may need a personal suffix if Apple says
   it's taken (free teams can't share IDs).
4. Plug in the iPhone, tap *Trust*, and turn on Settings → Privacy & Security
   → Developer Mode (restart).
5. `flutter run --release` (or Run in Xcode). First launch: Settings →
   General → VPN & Device Management → trust the developer app.

Free-team limits: 7-day expiry, at most 3 sideloaded apps per device, and no
push notifications / some capabilities. Background audio and PiP work.

Optional: turn on *Remote Login* (SSH) on the Mac so builds can be run from
the Linux dev machine; the iPhone stays plugged into the Mac.

## What needs an iOS version

Flutter code is shared. The native platform channels are Android-only today:

| Channel | Android | iOS plan |
|---|---|---|
| `openiptv/video_player` + `video_player_events/<id>` | `NativeVideoPlayer.kt` (ExoPlayer → texture) | **Swift AVPlayer** rendering through `AVPlayerItemVideoOutput` → `FlutterTexture`. Same methods (`create`, `open`, `play`, `pause`, `stop`, `seekTo`, `setSpeed`, `getTracks`, `selectTrack`, `clearTextTrack`, `dispose`) and the same events (`state`, `tracks`, `cues`, `error`), so `native_video_player.dart` is unchanged. Tracks = `AVMediaSelectionGroup` (audio, legible). |
| `openiptv/device` | TV detection, document picker check | Small Swift handler: never a TV; document picker always available. |
| `openiptv/pip` | Auto-PiP on Home | `AVPictureInPictureController` (needs an `AVPlayerLayer`) — phase 3b. |
| `openiptv/files` | Save backup to Downloads | Share sheet / Files app instead of Downloads. |
| `openiptv/updates` | Sideload self-updater | **Off on iOS** — updates come from Xcode/TestFlight/App Store. Hide the Settings rows. |
| `openiptv/cast` + `cast_events` | Google Cast | Phase 3b: Google Cast iOS SDK, plus AirPlay (#36). Hidden until then. |
| `openiptv/back`, `openiptv/tv_input` | Android Back key, TV keyboard | Not needed on iOS (swipe-back comes from the router). |

Plugins that already support iOS: SQLCipher/drift, flutter_secure_storage
(Keychain), audio_service, shared_preferences, path_provider, file_picker,
share_plus, package_info_plus, local notifications. `workmanager` on iOS only
gets occasional background time, so scheduled refresh becomes best-effort.

### Things AVPlayer won't play

- Raw MPEG-TS (`.ts`) live streams: for Xtream live, ask for `.m3u8`
  (the cast code already builds these candidates, `castCandidates`).
- MKV / some AVI movies: show the friendly "can't play this" message.
- Plain `http://` streams need App Transport Security exceptions
  (`NSAllowsArbitraryLoads` for media) in `Info.plist`.

## Phases

- **3a — launch and play HLS:** iOS builds and runs on the test iPhone;
  wizard, playlists, browse, search, details, profiles, parental controls;
  AVPlayer for HLS with captions/audio tracks; updater and casting hidden.
- **3b — polish:** PiP, background audio + lock-screen controls, backup
  save/restore via Files, AirPlay, Cast SDK, iPad layout pass.
- **3c — distribution (later, needs the paid account):** TestFlight, App
  Store metadata, privacy policy, review notes stressing "player only".
