> **OpenIPTV is in active development.** Some features are experimental while development goes on; features may be added, break and/or be removed at any time. New releases can come out several times a day as bugs are found and fixed. Thank you for testing! If anything doesn't work as it should, please report it on [GitHub Issues](https://github.com/Hunter-Clipper/OpenIPTV/issues). If you have a feature request, please open an issue on GitHub.

## What's new

**Fixes**
- Deleting a playlist from Settings now shows a professional loading dialog and closes automatically when finished, so the app no longer appears frozen on large playlists (#91).
- M3U playlists now parse in a streaming fashion (line-by-line via \`LineSplitter\` over a byte stream) instead of loading the entire file into memory as a \`List<String>\`. Eliminates the OOM risk on TV devices when loading large playlists (~18k channels) (#79).
- HTTP M3U downloads now use streaming HTTP (\`StreamedResponse\`) so bytes are decoded and discarded as they arrive, rather than buffering the full response body (#79).
- Playlist deletion is now wrapped in a database transaction to ensure reliability and data integrity during cleanup.

OpenIPTV is a player only — it does not provide any channels, streams or playlists. You need your own.

## Previous release (v0.14.27 — 2026-10-21)

**Fixes**
- M3U playlists now parse in a streaming fashion (line-by-line via \`LineSplitter\` over a byte stream) instead of loading the entire file into memory as a \`List<String>\`. Eliminates the OOM risk on TV devices when loading large playlists (~18k channels) (#79).
- HTTP M3U downloads now use streaming HTTP (\`StreamedResponse\`) so bytes are decoded and discarded as they arrive, rather than buffering the full response body (#79).

## Install
- **Phone or TV:** download app-release.apk below and open it (allow installing from this source when asked). On a TV, you can use the Downloader app with code 2687835.
- **From a computer:** adb install -r app-release.apk
- **Video in the car (optional, phones):** install it from Settings → Playback → Video in the Car, or download OpenIPTV-car-video.apk below.
- Already have OpenIPTV? It will offer this update automatically.

Earlier releases have been removed; this is the only current version.
