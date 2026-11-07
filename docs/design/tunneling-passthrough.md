# Audio passthrough and tunneled playback (#159)

Two optional settings under Settings → Advanced → Power User Tools (TVs),
each **Automatic / On / Off**, stored as prefs `audio_passthrough` and
`tunneled_playback` (also in backups). The native side (`OutputModes.kt`)
keeps its own copy too: Dart's start-up push can arrive before the channel
exists.

## How it works

- `OutputModes.wanted(...)` decides per player. Only the main player (the one
  holding audio focus) ever gets either feature; extra multi-view tiles, the
  car screen and any speed other than 1x always get plain PCM, untunneled.
- **Passthrough** is a custom `DefaultRenderersFactory.buildAudioSink`:
  Automatic = Media3's own (device-reported capabilities), Off =
  `AudioCapabilities.DEFAULT_AUDIO_CAPABILITIES` (PCM only), On = a forced
  list (AC-3, E-AC-3, E-AC-3 JOC, DTS, DTS-HD, TrueHD).
- **Tunneling** is `DefaultTrackSelector...setTunnelingEnabled(true)`, **live
  streams only** (`open(live:)`, from `/live/` URLs).
- A change (setting, multi-view start/end, a failure) calls
  `NativeVideoPlayer.refreshOutput()`, which rebuilds the player and carries
  on with the same stream (live: rejoins the live edge; movie: same position).
  Multi-view start/end comes from `MultiViewState` via `setMultiViewActive`.
- Safety nets: no first frame 4 s after READY, or the clock stuck with data
  buffered for 2.5 s (`checkTunnelFreeze`), or an audio-track / decoder error
  while a feature is on, switches that feature off (remembered for the
  session; for Automatic also across launches until the setting is changed),
  sends an `outputNotice` event; Dart (app.dart) then saves that setting as
  **Off** and PlayerScreen shows a plain-English snackbar. Defaults are
  Automatic for new installs and for existing users (no stored value).
- `[OTV-audio]` logs the encoding and whether tunneling is really in use;
  `[OTV-video] multiview ...` logs the switch.

## Spike results (Chromecast with Google TV, AMLS905D3, 2026-11-06)

- Tunneling works through the app's `SurfaceTexture` path at first (picture
  shows, `sync_mode:tunnel` in the audio HAL log) but the clock stalls after
  ~6 s on **catch-up** (every time, same show played fine untunneled) and
  also on live channels (clock stuck, ~50 s buffered, state BUFFERING).
  So `OutputModes.autoTunnelingDevice()` is false: Automatic never tunnels,
  "On" is experimental and falls back by itself.
- Catch-up and movies are never tunneled.
- Not yet tested: Mi TV (S7D), a receiver that really decodes passthrough
  (only the HDMI capability report can be checked on a stereo TV).

## Video layer (issue #162, 0.14.95)

Tunneled frames go to the display hardware, not into a Flutter texture, so
the picture needed a real on-screen layer. On TVs the main player now draws
on a `SurfaceView` (`VideoLayer.kt`) **behind** a see-through Flutter
surface (`MainActivity.getTransparencyMode`, `RenderMode.surface`).
- Dart reports where the picture goes (`VideoSurface`, `useLayer`); Flutter
  paints black around it and clears the picture area (`BlendMode.clear`), so
  the video shows through even over the guide's own background. The rect is
  read every frame (the pane moves when the category column opens).
- The layer exists (1 px) from app start; the main player claims it as each
  stream opens, so it is built (tunneled) on the layer from its first frame.
  Release is delayed 0.5 s so screen changes don't rebuild the player.
- A tunneled player starts every stream with a fresh decoder (reusing it
  across a size/profile change failed on the Chromecast).
- Multi-view, PiP, casting and the car use the old texture; multi-view
  releases the layer at once.
- Pane <-> full screen zoom: the player route is see-through; the picture's
  rect and corner radius (12 px -> square) animate from the pane's own;
  controls (`ZoomFade`) wait until it settles and hide as a zoom out starts.
- Setting (Power User Tools -> Video layer, `VideoLayerMode`): Automatic /
  On / Off, TVs only, applies after a restart. Automatic = on for every TV.
- Automatic tunneling is on for devices in
  `OutputModes.VERIFIED_TUNNELING_DEVICES` (Chromecast with Google TV,
  `sabrina`); add a device only after testing it.
- Testing notes: tunneled and hardware-plane video does not show in
  `screencap`; check `dumpsys SurfaceFlinger` for the sideband layer, the
  `[OTV-layer]`, `[OTV-switch]` and `[OTV-audio]` logs, or watch the TV.
- Not yet tested: Mi TV (S7D), PiP (the Chromecast has no PiP feature),
  car video on the head-unit emulator.
