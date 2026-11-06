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
  sends an `outputNotice` event and Dart shows a plain-English snackbar.
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
