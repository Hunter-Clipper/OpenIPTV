# Web browser client (issue #44)

Status: **in development (phase 6a runs in a browser; nothing released).** Branch
`feature/44-web-client`, draft PR #45. See [Current status](#current-status).

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

---

## Current status

Phase 6a works end to end in a browser. It has not been released, and the
web client has only been tried in Chromium so far.

### What works

- **Build and run:** `flutter build web --release` (about 4 minutes). The
  release build is one `main.dart.js` (about 1.3 MB gzipped) plus CanvasKit.
  The dev server (`flutter run -d web-server`) loads hundreds of small
  modules one after another and is several times slower to start; judge
  speed on a release build.
- **Storage:** Drift on WebAssembly (`web/sqlite3.wasm`, `web/drift_worker.js`),
  kept in the browser (IndexedDB). Profiles, playlists and channels survive
  a reload. The encrypted native database stays Android-only. Conditional
  imports pick the connection (`database_connection_native.dart` /
  `database_connection_web.dart`).
- **Playlists:** M3U links, and Xtream logins (channels, movies, series and
  the TV guide). Both were checked against a fake provider with a full-size
  catalog (18k channels, 36k movies, 8k series) and against a real
  provider by hand.
- **Video:** `<video>` with hls.js (HLS) and mpegts.js (`.ts`); scripts load
  on first use. A MutationObserver separates the browser's own "detached
  element" pause from a real pause so playback resumes without a reconnect.
- **Images:** `NetImage` shows posters and logos from hosts that block CORS
  by falling back to a plain `<img>` element. Android keeps the cached loader.
- **Polish:** path URLs (`/live`), tab title per screen, OpenIPTV favicon and
  install icons, a branded loading screen, a `[OTV-boot]` timing summary in
  the console.
- **Isolates:** browsers have none. `runOffMain` runs work on a background
  isolate on Android and in place on web (Xtream JSON, TV guide import); the
  guide parser yields to the page every few thousand events so a 100 MB
  guide doesn't freeze it.

### Developer tools

- **`/wipe.html`** clears the database, settings, cookies, cached files and
  service worker for that address. It is a separate static page, so it still
  works when the app is stuck. Open the app once with `?dev=1` to show a small
  "DEV · wipe data" link to it (`?dev=0` hides it again).
- Stale builds: Flutter installs a service worker that keeps its own copy of
  the app. After rebuilding, serve `index.html`, `main.dart.js`,
  `flutter_bootstrap.js` and `flutter_service_worker.js` with
  `Cache-Control: no-cache`, and use `/wipe.html` if a browser keeps the old
  app.
- Hosting needs an SPA fallback (every unknown path serves `index.html`); on
  GitHub Pages that means a copy of it as `404.html`.

### Known limits and not yet tested

- **CORS and mixed content** (the problem above) still block many providers'
  playlist links and streams. The self-hosted helper (6b) is the fix.
  Posters and logos are covered by `NetImage`.
- Backup export and import use native file APIs and are untested on web.
- `/settings/power-tools` is reachable by URL and shows Android-only VPN rows.
- Browser Back doesn't step through sub-screens that aren't go_router routes.
- The saved resume position is ignored by the web player.
- Search for non-English letters is case-sensitive (SQLite `LIKE` only folds
  ASCII).
- A guide that is gzipped without a `Content-Encoding` header can't be
  unpacked on web.
- Not tried: movie and series detail playback, `.ts` streams, Firefox and
  Safari, a real TV-sized browser window.
- Start-up is CPU-bound at about 4 s to the first frame in a headless
  browser (WebAssembly and app start), and the database is ready about
  1 s later. Ideas not done: deferred loading of rarely used screens, a
  WebAssembly build of the app (blocked by `dart:ffi` in the import graph),
  self-hosted CanvasKit, and brotli on the host.

### Phases

| Phase | Status |
|---|---|
| 6a runs in a browser | Working; in review on PR #45 |
| 6b self-hosted helper | Not started |
| 6c polish (backup, desktop layout, keyboard shortcuts, storage notice) | Not started |
