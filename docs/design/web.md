# Web browser client (issue #44)

Status: planned, not started. Branch `feature/44-web-client`.

## Goal

Open OpenIPTV in a desktop browser (Chrome, Edge, Firefox, Safari): add a
playlist, browse, search and watch, with nothing to install.

## The hard part: browsers block most IPTV servers

This is the deciding issue, and it's a browser rule, not a Flutter one:

1. **CORS.** A web page can only read a playlist, Xtream API reply or TV
   guide from another server if that server allows it (CORS headers).
   Almost no IPTV provider does, so loading the catalog fails in a browser
   even though the same request works in the Android app.
2. **Mixed content.** A site served over `https://` can't load `http://`
   streams, and most provider links are plain `http://`.

Video segments themselves are often fetched fine by the browser's player,
but the playlist/API/guide requests (and http streams) are blocked.

Ways around it:

| Option | How | Trade-off |
|---|---|---|
| **A. Self-hosted helper** (recommended) | A tiny optional "OpenIPTV Web" server (Docker image / single binary) the **user runs on their own PC or NAS**. It serves the web app and forwards the user's own playlist/API/guide requests (and http streams) from their own network. | Works with every provider. The project never hosts or relays anyone's streams — each user runs their own. One extra install step. |
| B. Public hosting + browser only | Host on GitHub Pages; only works with providers that already send CORS headers and https links (e.g. iptv-org). | Zero install, but most real playlists won't load. |
| C. Public proxy run by the project | Host a proxy for everyone. | **Not acceptable**: the project would be relaying streams — breaks the "player only, no content" rule and the legal position. |

Plan: ship **A** as the real web client, with **B** working automatically for
providers that allow it (and for a public demo with iptv-org).

## What needs a web version

| Piece | Android today | Web plan |
|---|---|---|
| **Video player** (`openiptv/video_player`) | ExoPlayer | An HTML `<video>` element shown with `HtmlElementView`; **hls.js** for HLS (Safari plays HLS natively), **mpegts.js** for `.ts` live. Same Dart `NativeVideoPlayer` API. Captions/audio tracks via the players' track APIs. |
| Database | Drift + SQLCipher | Drift's web backend (SQLite compiled to WebAssembly, stored in the browser's OPFS/IndexedDB). **No SQLCipher on web** — logins sit in browser storage; say so plainly in Settings and suggest the self-hosted helper keeps them on the user's own machine. |
| Secure key store | Android Keystore | Not available; see above. |
| Background refresh, notifications, PiP, casting, updater | Android services | Refresh on open / timer; browser's own PiP and full-screen buttons; no updater (the page is always the latest). Casting from Chrome could come later. |
| Backup | Files | Browser download / file upload. |
| Back button | Android Back | Browser back via go_router's URL routing (deep links come for free). |

## Layout

Desktop-style: the TV layout's side rail, mouse hover, scroll-wheel rows,
keyboard shortcuts in the player — shared with the Windows client (#27).
Narrow windows fall back to the phone layout.

## Updates and releases (applies to every client)

Each client must only ever update from **its own** file, never another
platform's:

- One GitHub release per version, carrying a file per platform with a
  fixed name: `app-release.apk` (Android — fixed forever, old installs and
  the TV Downloader code depend on it), `OpenIPTV-windows.zip`, and later
  others. The updater matches its file by exact name and ignores a
  release that doesn't include it (done for Android in 0.10.128).
- Because only the newest release is kept, a release must still carry the
  current Android APK even when only another platform changed — otherwise
  the Downloader code and older Android updaters lose their download.
- The web client never self-updates; the page is always the latest.

## Phases

- **6a — runs in a browser:** `flutter build web`, deployed to GitHub Pages;
  iptv-org playlist loads and plays (HLS via hls.js); drift on web.
- **6b — self-hosted helper:** small server that serves the app and forwards
  the user's requests; Docker image + README steps; any provider works.
- **6c — polish:** mpegts.js for `.ts`, desktop layout/keyboard, backup
  download/upload, clear notice about where logins are stored.
