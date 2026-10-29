# Windows client (issue #27) — an Electron app around the web client

Status: planned, not started. Branch `feature/27-windows-client`.

This **replaces the earlier plan** (a native Flutter Windows build with
media_kit/libmpv, SQLCipher and OpenSSL). That plan is still in this branch's
git history (commit `2787c72`) and is the fallback if the first step below
fails. macOS (the other half of #27) still waits with the rest of the Apple
work (#25), though the same shell could produce a Mac build later.

Depends on the web client (#44, PR #45): the Windows app is that web app in
its own window, so PR #45 has to land first (or this branch is rebased onto
it).

## Goal

The same app on a Windows 10/11 PC: add playlists, browse, search and watch
with a mouse and keyboard, in a resizable window or full screen, installed
like any other program.

## Why Electron, and what it fixes

The web client works, but a web page is boxed in by the browser. The
biggest box is **CORS and mixed content**: almost no IPTV provider lets a
website read its playlist, and an `https://` page can't load `http://`
streams. The web plan answered that with a self-hosted helper the user has
to install and run (phase 6b of `docs/design/web.md`).

Electron removes the box. It is the same Chromium engine, but it is **an app
on the user's own PC**, so its shell can allow the app's requests to any
provider, including plain `http://`. That is the job of the helper, with
nothing extra to install. It also fits the no-content rule: the project
still hosts and relays nothing; each person's app talks to their own
provider from their own computer.

Other reasons:

- Almost all the code is reused: the Flutter web build, the browser
  database, the hls.js / mpegts.js player and the image handling.
- It is far less work than a native Flutter Windows port.
- The Android code is not touched.

Costs to accept:

- A bigger download (about 100 MB or more) and more memory than a native
  app.
- **Audio and video formats are Chromium's, not "everything".** H.264 and
  AAC are fine. **AC3 / E-AC3 surround audio** (common on IPTV), H.265 and
  some other formats may not play, depending on the PC and the Electron
  version. This is the one real risk, so the plan starts with a test (phase
  0).
- Windows warns about unsigned installers (SmartScreen: "More info → Run
  anyway"). A code-signing certificate removes it but costs money, so not
  for now.

## How it fits together

New folder `desktop/` (not `windows/`, so a Mac or Linux build can share it
later). Nothing in `lib/` has to know about it except where listed below.

| Piece | What it does |
|---|---|
| **Main process** (`desktop/main.js`) | One window; one running copy of the app; remembers window size and position; F11 / full screen; menu; media keys; opens links in the default browser. |
| **App address** | The Flutter build is served from a private `app://openiptv/` address with the single-page fallback (the app uses path URLs like `/live`), so it never needs a web server or a network port. |
| **Provider access** | In the main process, response headers for provider, image and stream requests are rewritten so the page may read them, and `http://` content is allowed. This applies only to this app's window on the user's own PC. |
| **Preload bridge** (`desktop/preload.js`) | A tiny, fixed list of calls the page may make (see below), with context isolation on and Node access off. |
| **Storage** | The browser database (IndexedDB, SQLite compiled to WebAssembly) lives in the app's data folder. Provider logins stay unencrypted there to begin with; encrypting them with Windows' own credential storage (Electron `safeStorage`) is phase 2. |

Bridge calls (the whole list, nothing else is exposed): open / save file
dialogs for backups, app version, check for and install updates, open a link
in the default browser, window controls.

## What changes in the Dart app

Small, and guarded so Android and the plain web build behave as before:

- **Detect the shell** with a `window.openiptvDesktop` flag set by the
  preload script. The web-only notices ("some playlists won't load in a
  browser") and the dev-only hints are hidden when it is present.
- **Backup export and import** use the bridge's file dialogs. These are still
  untested on the web build, so they get done and tested here first.
- **Layout and input:** the TV layout (side rail, wide rows) already suits a
  big window. Add hover highlights, the scroll wheel on horizontal rows, a
  right-click that opens the long-press menu, and player shortcuts (Space,
  arrows, F for full screen, Esc).
- **Updater:** a Windows branch in `update_service.dart` (see below).
- Web gaps from `docs/design/web.md` that matter here and get closed on the
  way: resume position, the Android-only power-tools page, back-button
  behaviour for sub-screens.

## What each Android piece becomes

| Piece | Android today | Windows (Electron) |
|---|---|---|
| Video player | ExoPlayer | `<video>` with hls.js and mpegts.js, as on the web. Codec limits above. |
| Database | Drift + SQLCipher | Drift on WebAssembly, as on the web (not encrypted at first). |
| Secure key store | Android Keystore | `safeStorage` (Windows DPAPI) in phase 2. |
| Scheduled refresh | workmanager | Not available. Refresh on start-up and on a timer while the app is open. |
| Media notification | audio_service | Windows media keys through the shell; an overlay later (optional). |
| Self-updater | Download APK, hand to installer | Check GitHub releases like the Android updater, download the Windows file and run it (see below). |
| Backup save / restore | Downloads / document picker | Normal Windows Save and Open dialogs. |
| Casting, Android Auto, TV keyboard | | Not on Windows at first. The browser's own Picture-in-Picture may come later. |

## Phase 0: a go / no-go test (1–2 days)

Before building anything else: a bare Electron window around the current web
build, tried with real streams. Pass or fail on each:

1. Provider playlists, APIs and images load without the CORS help of any
   outside server (Xtream and M3U).
2. `http://` streams play (HLS and `.ts`).
3. Audio: AC3 and E-AC3 channels. H.265 and MPEG-2 video.
4. A long session: memory stays steady over hours; channel switching is quick.
5. The database survives restarts and updates.

If audio formats fail, the options are, in order: (a) re-encode audio in the
main process with a bundled ffmpeg (extra size and a licence to document);
(b) fall back to the native Flutter plan in this branch's history. If the
rest passes, the work continues as below.

Most of this can be tested on Linux (same Chromium); installer, signing and
anything Windows-specific need a Windows PC or the CI runner.

## Build and CI

A GitHub Actions workflow on a free Windows runner: set up Flutter, run
`flutter build web --release`, copy the result into `desktop/`, then package
with electron-builder into an installer and a portable zip, and attach both to
the run. To test, download on any Windows PC and run it. A Linux build of the
same shell is used for quick tests here.

## Security rules for the shell

- Context isolation on, Node access off in the page, a minimal fixed bridge.
- The window may only load the app's own `app://` address; every other link
  opens in the default browser.
- No remote code: hls.js and mpegts.js ship inside the app.
- The header changes apply to the app's own requests only and are never
  applied to other windows.
- The shell bundles and links no playlists or streams (the no-content rule
  in the README applies unchanged).

## Updates and releases (applies to every client)

Each client must only ever update from **its own** file, never another
platform's:

- One GitHub release per version, carrying a file per platform with a fixed
  name: `app-release.apk` (Android: fixed forever, old installs and the TV
  Downloader code depend on it), `OpenIPTV-windows.zip` (the portable app),
  `OpenIPTV-windows-setup.exe` (the installer), and later others. The updater
  matches its file by exact name and ignores a release that doesn't include
  it (done for Android in 0.10.128).
- Because only the newest release is kept, a release must still carry the
  current Android APK even when only another platform changed.
- The web client never self-updates; the page is always the latest.
- **Decision:** the Windows app uses its own updater (same GitHub check as
  Android, exact file name), not Electron's stock auto-updater. The stock one
  needs its own manifest file and differential files next to the installer,
  which doesn't fit "one release, a fixed-name file per platform".
- A release is only ever cut with the owner's explicit go-ahead.

## Phases

- **0: go / no-go test** (above).
- **1: it runs:** the shell, the Windows build in CI, the app opens, setup
  wizard, playlists (including providers a browser can't reach), browse,
  search, playback.
- **2: feels native:** mouse and keyboard polish, full screen, window size
  remembered, Save / Open dialogs for backups, refresh timer, encrypted
  logins with `safeStorage`.
- **3: shipping:** installer and zip on GitHub releases, in-app updates,
  README install steps, licence notices for Electron and its media
  libraries in `docs/THIRD_PARTY_NATIVE.md`.

## Open questions for the owner

- Installer, portable zip, or both for the first test builds (the plan above
  produces both).
- Code signing: later, when it's worth the cost?
- Do we want a tray icon or mini player (the old issue checklist had one as
  optional)?
- Keep the folder name `desktop/` so macOS and Linux builds can reuse the shell
  later?
