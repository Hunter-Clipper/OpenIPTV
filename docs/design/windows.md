# Windows client (issue #27)

Status: planned, not started. Branch `feature/27-windows-client`.
macOS (the other half of #27) waits with the rest of the Apple work (#25).

## Goal

The same app on a Windows 10/11 PC: add playlists, browse, search and watch
with a mouse and keyboard, in a resizable window or full screen.

## How it gets built (no Windows setup needed)

Flutter can't build Windows apps from Linux, but **GitHub Actions has free
Windows build machines**. A workflow on this repo runs `flutter build windows`
on every push to the branch and attaches a zip of the app to the run. To test,
download the zip on any Windows PC, unzip and run `OpenIPTV.exe`.

Releases later add the Windows zip (and an installer) next to `app-release.apk`.
Unsigned apps show a Windows SmartScreen "unknown publisher" warning
("More info → Run anyway"); a code-signing certificate removes it but costs
money, so not for now.

## What needs a Windows version

The Flutter UI is shared. Android-only pieces:

| Piece | Android today | Windows plan |
|---|---|---|
| **Video player** (`openiptv/video_player`) | ExoPlayer (`NativeVideoPlayer.kt`) | **media_kit (libmpv)** behind the same Dart `NativeVideoPlayer` API — plays HLS, MPEG-TS, MKV, everything. (mpv was dropped on Android for low-end TV hardware; PCs don't have that problem.) |
| Database encryption | SQLCipher + Android Keystore | SQLCipher is supported on Windows (needs OpenSSL at build time — install it in the CI job); key kept by flutter_secure_storage (Windows Credential Manager / DPAPI). |
| Scheduled refresh | workmanager | Not available on Windows → refresh on start-up and on a timer while the app is open. |
| Media notification | audio_service | Windows media keys / overlay later (optional). |
| Self-updater | Download APK → installer | Check GitHub releases the same way; download the new zip/installer and open it. |
| Backup save / restore | Downloads folder / document picker | Normal Windows Save / Open dialogs (file_picker supports them). |
| Casting, PiP, Android Auto, TV keyboard | | Not on Windows at first (casting from a PC could come later). |

## Layout

The TV layout (side navigation rail, wide rows) already suits a big window.
Use it on Windows, plus mouse support: hover highlights, scroll-wheel on
horizontal rows, right-click = the long-press menu, keyboard shortcuts in
the player (Space, arrows, F for full screen, Esc).

## Phases

- **5a — it runs:** Windows build in GitHub Actions; app opens, setup
  wizard, playlists, browse, search; media_kit player plays live and VOD.
- **5b — feels native:** mouse/keyboard polish, full screen, window size
  remembered, Save/Open dialogs for backups, refresh timer, encrypted DB.
- **5c — shipping:** Windows zip + installer on GitHub releases, in-app
  updates, README install steps.
