# Desktop client (issue #27) — an Electron app around the web client

Windows first, then Linux. Status: planned, not started. Branch
`feature/27-windows-client` (the name stays so the PR and issue links keep
working).

This **replaces the earlier plan** (a native Flutter Windows build with
media_kit/libmpv, SQLCipher and OpenSSL). That plan is still in this branch's
git history (commit `2787c72`, as `docs/design/windows.md`) and is the
fallback if the first step below fails. macOS (the other half of #27) still
waits with the rest of the Apple work (#25), though the same shell could
produce a Mac build later.

Depends on the web client (#44, PR #45): the desktop app is that web app in
its own window, so PR #45 has to land first (or this branch is rebased onto
it).

## Goal

The same app on a Windows 10/11 PC and on a Linux desktop: add playlists,
browse, search and watch with a mouse and keyboard, in a resizable window or
full screen, installed like any other program.

## Why Electron, and what it fixes

The web client works, but a web page is boxed in by the browser. The
biggest box is **CORS and mixed content**: almost no IPTV provider lets a
website read its playlist, and an `https://` page can't load `http://`
streams. The web plan answered that with a self-hosted helper the user has
to install and run (phase 6b of `docs/design/web.md`).

Electron removes the box. It is the same Chromium engine, but it is **an app
on the user's own computer**, so its shell can allow the app's requests to
any provider, including plain `http://`. That is the job of the helper, with
nothing extra to install. It also fits the no-content rule: the project
still hosts and relays nothing; each person's app talks to their own
provider from their own computer.

Other reasons:

- Almost all the code is reused: the Flutter web build, the browser
  database, the hls.js / mpegts.js player and the image handling.
- It is far less work than native Flutter ports for each system.
- One shell serves both systems (and a Mac later). The Android code is not
  touched.

Costs to accept:

- A bigger download (about 100 MB or more) and more memory than a native
  app.
- **Audio and video formats are Chromium's, not "everything".** H.264 and
  AAC are fine (Electron carries its own copy, so this holds on every Linux
  distro too). **AC3 / E-AC3 surround audio** (common on IPTV), H.265 and
  some other formats may not play, depending on the computer and the
  Electron version. This is the one real risk, so the plan starts with a
  test (phase 0). Linux is the weaker case, because it has no system
  decoders to lean on for those formats.
- Windows warns about unsigned installers (SmartScreen: "More info → Run
  anyway"). A code-signing certificate removes it but costs money, so not
  for now. Linux has no equivalent warning.

## How it fits together

New folder `desktop/`. Nothing in `lib/` has to know about it except where
listed below.

| Piece | What it does |
|---|---|
| **Main process** (`desktop/main.js`) | One window; one running copy of the app; remembers window size and position; F11 / full screen; menu; media keys; opens links in the default browser. |
| **App address** | The Flutter build is served from a private `app://openiptv/` address with the single-page fallback (the app uses path URLs like `/live`), so it never needs a web server or a network port. |
| **Provider access** | In the main process, response headers for provider, image and stream requests are rewritten so the page may read them, and `http://` content is allowed. This applies only to this app's window on the user's own computer. |
| **Preload bridge** (`desktop/preload.js`) | A tiny, fixed list of calls the page may make (see below), with context isolation on and Node access off. |
| **Storage** | The browser database (IndexedDB, SQLite compiled to WebAssembly) lives in the app's data folder. Provider logins stay unencrypted there to begin with; encrypting them with the system's own credential storage (Electron `safeStorage`) is phase 2. |

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
- **Updater:** a desktop branch in `update_service.dart` (see below).
- Web gaps from `docs/design/web.md` that matter here and get closed on the
  way: resume position, the Android-only power-tools page, back-button
  behaviour for sub-screens.

## What each Android piece becomes

| Piece | Android today | Windows and Linux (Electron) |
|---|---|---|
| Video player | ExoPlayer | `<video>` with hls.js and mpegts.js, as on the web. Codec limits above. |
| Database | Drift + SQLCipher | Drift on WebAssembly, as on the web (not encrypted at first). |
| Secure key store | Android Keystore | `safeStorage` in phase 2: Windows DPAPI; on Linux the desktop keyring (GNOME Keyring or KWallet). With no keyring running, Electron falls back to weak plain storage, so the app shows a notice instead of pretending logins are protected. |
| Scheduled refresh | workmanager | Not available. Refresh on start-up and on a timer while the app is open. |
| Media notification | audio_service | System media keys through the shell (on Linux the standard media-control interface, MPRIS, which Chromium already supports); an overlay later (optional). |
| Self-updater | Download APK, hand to installer | Check GitHub releases like the Android updater, download the file for this system and run it (see below). |
| Backup save / restore | Downloads / document picker | The system's Save and Open dialogs. |
| Casting, Android Auto, TV keyboard | | Not on desktop at first. The browser's own Picture-in-Picture may come later. |

## Phase 0: a go / no-go test (1–2 days)

Before building anything else: a bare Electron window around the current web
build, tried with real streams. Pass or fail on each:

1. Provider playlists, APIs and images load without the CORS help of any
   outside server (Xtream and M3U).
2. `http://` streams play (HLS and `.ts`).
3. Audio: AC3 and E-AC3 channels. H.265 and MPEG-2 video.
4. A long session: memory stays steady over hours; channel switching is quick.
5. The database survives restarts and updates.
6. **Repeat 1–5 on Linux**, which has the weaker format support, on both X11
   and Wayland, and check the shell's sandbox starts on a stock Ubuntu LTS and
   a Fedora install.

If audio formats fail, the options are, in order: (a) re-encode audio in the
main process with a bundled ffmpeg (extra size and a licence to document);
(b) fall back to the native Flutter plan in this branch's history. Flutter
builds for Linux too, and libmpv plays almost anything there, so the
fallback covers both systems.

Most of this can be tested on the development machine, which runs Linux:
the same Chromium, including a headless run of the whole app. Installer,
signing and anything Windows-specific need a Windows PC or the CI runner.

## Build and CI

GitHub Actions, free runners:

- **Windows runner:** set up Flutter, `flutter build web --release`, copy
  the result into `desktop/`, package with electron-builder into an
  installer and a portable zip, attach both to the run.
- **Ubuntu runner:** the same, packaged as an AppImage. `.deb` and `.rpm`
  come from the same config if we decide to ship them.

To test, download on any machine and run it.

## Security rules for the shell

- Context isolation on, Node access off in the page, a minimal fixed bridge.
- The window may only load the app's own `app://` address; every other link
  opens in the default browser.
- No remote code: hls.js and mpegts.js ship inside the app.
- The header changes apply to the app's own requests only and are never
  applied to other windows.
- The shell bundles and links no playlists or streams (the no-content rule
  in the README applies unchanged).
- Keep Chromium's sandbox on. On Linux that means shipping the build so it
  starts with the sandbox intact (not a blanket "no sandbox" flag).

## Updates and releases (applies to every client)

Each client must only ever update from **its own** file, never another
platform's:

- One GitHub release per version, carrying a file per platform with a fixed
  name: `app-release.apk` (Android: fixed forever, old installs and the TV
  Downloader code depend on it), `OpenIPTV-windows.zip` (the portable app),
  `OpenIPTV-windows-setup.exe` (the installer), `OpenIPTV-linux.AppImage`,
  and later others. The updater matches its file by exact name and ignores a
  release that doesn't include it (done for Android in 0.10.128).
- Because only the newest release is kept, a release must still carry the
  current Android APK even when only another platform changed.
- The web client never self-updates; the page is always the latest.
- **Decision:** the desktop apps use their own updater (same GitHub check as
  Android, exact file name), not Electron's stock auto-updater. The stock one
  needs its own manifest file and differential files next to the installer,
  which doesn't fit "one release, a fixed-name file per platform".
- **Linux:** the AppImage is the main download because it can replace itself
  like the Windows file. `.deb` / `.rpm` installs would update through the
  user's package manager instead, so they are optional extras, not the
  default.
- A release is only ever cut with the owner's explicit go-ahead.

## Phases

- **0: go / no-go test** (above), Windows and Linux.
- **1: it runs on Windows:** the shell, the Windows build in CI, the app
  opens, setup wizard, playlists (including providers a browser can't
  reach), browse, search, playback.
- **2: feels native:** mouse and keyboard polish, full screen, window size
  remembered, Save / Open dialogs for backups, refresh timer, encrypted
  logins with `safeStorage`.
- **3: Windows shipping:** installer and zip on GitHub releases, in-app
  updates, README install steps, licence notices for Electron and its media
  libraries in `docs/THIRD_PARTY_NATIVE.md`.
- **4: Linux:** the Ubuntu CI build and AppImage, keyring storage with its
  notice, the Linux updater branch, README steps, then a pass on X11 and
  Wayland. Much of this can start alongside phases 1–2 because the shell is
  shared.

## Decisions so far (owner, 2026-10-29)

- **Order:** the phase 0 test and closing the web-client gaps (backup,
  resume position, the power-tools page, Back button) run in parallel.
- **Test machines:** a Windows 11 PC and a separate Linux desktop, plus the
  development machine (Linux). Windows 10 is not covered and is noted as
  untested.
- **If AC3 / E-AC3 audio fails in Electron:** decide after the test, with the
  real cost of each option (re-encode audio in the app, or go native).
- **Linux downloads:** AppImage only for now (`OpenIPTV-linux.AppImage`).

## Still open

- Windows: installer, portable zip, or both for the first test builds (the
  plan above produces both).
- Windows code signing: later, when it's worth the cost?
- Linux: which distros to promise to test (suggest Ubuntu LTS and Fedora);
  `.deb` / `.rpm` or a Flatpak later?
- Do we want a tray icon or mini player (the old issue checklist had one as
  optional)?
- Keep the folder name `desktop/` so macOS builds can reuse the shell later?
