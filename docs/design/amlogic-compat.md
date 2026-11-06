# Amlogic compatibility / graphics mode (issue #157)

**Goal:** a TiviMate-style "Amlogic fix" — but built on measurements, not on
a guess at what another app's switch does (nothing official describes it).

## What was verified

Research (sources in issue #157): the documented Amlogic video problems are
on the older `OMX.amlogic.*.awesome` decoders (interlaced H.264 stalls,
halved interlaced size). `setEnableDecoderFallback` does not catch a silent
stall. Both test TVs use the newer `c2.amlogic.*` decoders instead.

On the owner's TVs, with generated streams (progressive and truly
interlaced H.264 and MPEG-2, 720p60, 1080p50, HEVC 1080p and 4K) and 80
quick channel zaps:

- **Chromecast with Google TV** (S905D3, Mali-G31): every stream decodes in
  hardware and plays; no dropped frames, codec errors or stalls.
- **Mi TV** (Amlogic S7D = AMLS905X5M, Mali-G310, 4K panel): decoder and
  stream are fine too (720p60 on `c2.amlogic.avc.decoder`, source timestamps
  regular, frames released to the display every 16.67 ms, no drops). Yet the
  picture tears. The cause is in how Flutter puts the video texture on
  screen, not in the decoder.

## How tearing was measured

`tools/tear-test/`: a stream whose frames carry their own number three times
(top/middle/bottom) and a script that reads that from screenshots. Different
numbers in one screenshot = a torn frame. Control (two frames stitched):
detected, also after scaling.

| Device | Graphics path | Screenshots | Torn |
|---|---|---|---|
| Mi TV (S7D) | Impeller / Vulkan (Flutter default) | 400 | 7 (1.75%) |
| Mi TV (S7D) | Skia (Impeller off) | 899 | 0 |
| Chromecast (S905D3) | Impeller / Vulkan | 450 | 0 |
| Chromecast (S905D3) | Skia | 100 | 0 |

Presentation timing (SurfaceFlinger, 10 s of 720p60): Impeller 0.7% missed
refreshes, interval spread 1.36 ms; Skia 0.2%, 0.68 ms. CPU and memory are
about the same.

So tearing is **not** "all Amlogic" — it is this chip/GPU path. Impeller's
OpenGL ES backend can't be requested in release builds (the engine keeps
Vulkan; tried via manifest and shell args), so Skia is the only alternative.

## What was built

**TVs only.** Phones and tablets never see the setting, `GraphicsMode.apply`
returns before touching Flutter, and the logging is not attached.

- Settings → Advanced → Power User Tools → **Graphics mode**: Automatic /
  Standard / Compatible. Shows the chip (`AMLS905X5M · s7d`) and what is in use.
  Applies after a restart (offered in one tap).
- `GraphicsMode.kt`: runs in `Application.onCreate`, before the first Flutter
  engine, and starts Flutter's loader with `--enable-impeller=false` when the
  mode is compatible. Automatic = compatible only on chips with measurements
  (SoC model `AMLS905X5M` / board `s7d`). **Add a chip to the list only with a
  tear-test result.**
- `RestartActivity.kt`: restarts from a separate `:restart` process (the
  app can't relaunch itself and then kill its own process).
- `VideoDiagnostics.kt` / `FrameCadence.kt`: `[OTV-video]` (decoder, formats,
  dropped frames) and `[OTV-cadence]` (frame rate, source and release
  timing every 5 s) in logcat.

## Known limits

- Flutter marks the Impeller opt-out as deprecated. If a future Flutter
  removes it, Compatible becomes a no-op; re-run the tear test then.
- The tear test sees tears inside the app's own picture. A tear made later,
  at the display, can't be seen in a screenshot.
- Not tested: other Amlogic chips (S905X/X2/X3/X4, Mi Box S), other GPUs.
  They get Standard unless the user picks Compatible; reports welcome.
