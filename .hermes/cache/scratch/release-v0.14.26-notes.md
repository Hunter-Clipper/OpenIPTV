> **OpenIPTV is in active development.** Some features are experimental while development goes on; features may be added, break and/or be removed at any time. New releases can come out several times a day as bugs are found and fixed. Thank you for testing! If anything doesn't work as it should, please report it on [GitHub Issues](https://github.com/Hunter-Clipper/OpenIPTV/issues). If you have a feature request, please open an issue on GitHub.

## What's new

**Fixes**
- Picture-in-Picture no longer starts from non-player screens (settings, guide, channel list). PiP is now only offered when the full-screen player is active and playback is running (#88).
- PiP defaults to off on Android TV (where the screen is the TV itself), while remaining on for phones and tablets. Users can still enable it in Settings → Picture-in-Picture (#88).
- PiP is now suppressed while the player's channel switcher or multi-view overlay is open. Pressing Home with these overlays open now stops playback instead of letting the stream continue silently in the background (#88).

## Previous release (v0.14.25 — PiP overlay suppression)
- PiP is now suppressed while the player's channel switcher or multi-view overlay is open.
- When PiP is suppressed by an overlay, pressing Home stops playback instead of letting the stream continue silently.

OpenIPTV is a player only — it does not provide any channels, streams or playlists. You need your own.

## Install
- **Phone or TV:** download app-release.apk below and open it (allow installing from this source when asked). On a TV, you can use the Downloader app with code 2687835.
- **From a computer:** adb install -r app-release.apk
- **Video in the car (optional, phones):** install it from Settings → Playback → Video in the Car, or download OpenIPTV-car-video.apk below.
- Already have OpenIPTV? It will offer this update automatically.

Earlier releases have been removed; this is the only current version.