# OpenIPTV brand

Source artwork for the app icon, splash screen, Android TV banner and in-app
logo ("Open Ring": a gradient ring left open at the top — the O of Open —
around a play button).

- Brand gradient: `#8B5CF6` (violet) → `#3B82F6` (blue) → `#22D3EE` (cyan)
- Ink background: `#0A0A12` (tile glow from `#1E1B36`)
- Wordmark: "Open" in Google Sans Medium + "IPTV" in Google Sans Bold with the
  gradient.

| File | Use |
| --- | --- |
| `icon.svg` | full-bleed app icon (the OS rounds the corners) |
| `icon_tile.svg` | rounded tile, for marketing/README |
| `mark.svg` | mark on transparent, with glow (adaptive icon foreground, in-app logo, splash) |
| `mark_mono.svg` | single-colour mark (themed/monochrome icon, notification icon) |
| `wordmark.svg` | "OpenIPTV" wordmark |
| `tv_banner.svg` | Android TV / Fire TV launcher banner |

Run  (needs Firefox, Pillow, numpy) to
re-export everything below after editing an SVG.

Run `python3 assets/branding/export.py` (needs Firefox, Pillow and numpy) to
re-export everything below after editing an SVG.

Exports: `png/` holds the sources for the generated launcher icons and
splash (not bundled in the app); `assets/images/logo_mark.png` and
`assets/images/wordmark.png` are the in-app logo. Regenerate the Android/iOS
icons and splash with `dart run flutter_launcher_icons` and
`dart run flutter_native_splash:create`. The TV banner
(`android/.../res/drawable*/tv_banner.png`) and notification icon
(`ic_stat_open_iptv`) are exported directly from `tv_banner.svg` and
`mark_mono.svg`.
