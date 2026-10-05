# Casting to TVs and speakers (Chromecast / AirPlay)

Status: **planning** — tracks [#32](https://github.com/Hunter-Clipper/OpenIPTV/issues/32).

## Goal

From the phone, send what's playing — a live channel, a movie or an
episode — to a Chromecast / Google TV (and, with the iOS port, AirPlay),
and control it from the phone.

## User experience

- A **Cast** button in the player's action row (and on movie / series
  detail pages) that only appears when a cast device is on the same
  network. Tapping it lists devices.
- Picking a device moves playback there: movies and episodes continue from
  the same position; live channels start at the live edge. The phone's
  video stops (some provider accounts allow only one connection).
- While casting, the phone player becomes a remote: play / pause, seek and
  ±10 s, volume, channel list / next and previous channel on Live TV, and
  a clear "Playing on Living Room TV" banner. The Now Playing notification
  and lock screen show the cast session.
- Stop casting (or disconnect) → playback returns to the phone at the same
  point.
- Plain-English messages when something can't be cast, e.g. "This channel
  can't be played on Living Room TV."

## Technical plan (Android)

1. **Cast SDK + Media3 `CastPlayer`.** Add `androidx.media3:media3-cast`
   (Google Cast SDK). Keep the existing native ExoPlayer for local playback
   and switch the session to a `CastPlayer` when a cast session starts;
   both implement Media3's `Player`, so the controls layer talks to one
   interface. Needs an `OptionsProvider` in the manifest and the Default
   Media Receiver app id (no custom receiver to start).
2. **Native ↔ Dart.** Extend `NativeVideoPlayer.kt` / `openiptv/video_player`
   with cast session state (available devices, connected device name,
   position) as events, and methods to start / stop casting. The Cast
   button is the SDK's `MediaRouteButton`, shown via a small platform view,
   or a Flutter button that opens the route chooser through a method call.
3. **Media metadata.** Send title, channel / series name and artwork with
   each item so the TV shows something sensible.
4. **Hand-off.** On session start: read local position → pause local →
   load on receiver at that position. On session end: read receiver
   position → resume locally.
5. **Live TV channel switching** while casting reuses `_tuneTo` but loads
   the new URL on the receiver.

## Stream compatibility (the main risk)

The receiver fetches and plays the URL itself:

| Source | Expected on the Default Media Receiver |
|---|---|
| HLS (`.m3u8`) | Generally plays |
| MP4 movies / episodes | Generally plays |
| MPEG-TS (`.ts`) — most Xtream live channels | Often **not** supported |
| MKV / AVI movies | Often not supported |
| http-only URLs, cross-protocol redirects | May be refused by the receiver |

Mitigations, in order:
- For Xtream, request live channels as HLS when the provider allows it.
  The login response lists `allowed_output_formats` (currently ignored —
  the app always asks for `.ts`); build the cast URL with `m3u8` when it's
  in the list.
- Detect a failed load and show the plain-English message instead of a
  silent black screen.
- Later, if needed: a custom (Styled) Web Receiver with broader format
  support — requires registering a receiver app id.

## Privacy and security

- Xtream stream links contain the account login, so casting necessarily
  hands that link to the receiving device. Say so in the docs; never log
  it (use `redactUrl`).
- Single-connection accounts: always stop the phone's own stream before
  the receiver starts.

## Licensing / distribution

- The Google Cast SDK is part of Google Play Services. That conflicts with
  the project's F-Droid-friendly goal, so casting should live in a
  **Play-services build flavour** (the default GitHub APK) with an
  F-Droid flavour that leaves it out. Decide flavours before merging.

## AirPlay

Native to Apple platforms only; it comes with the iOS port
([#25](https://github.com/Hunter-Clipper/OpenIPTV/issues/25)) via
`AVRoutePickerView`. Not possible from Android.

## Testing

- Real devices: the user's Pixel → Chromecast with Google TV on the same
  Wi-Fi.
- Cases: live HLS, live `.ts` (expect the friendly message unless HLS is
  available), MP4 movie with resume, channel switching while casting,
  disconnect mid-stream, phone locked during casting, single-connection
  account.
- Unit tests: cast URL builder (format selection from
  `allowed_output_formats`), hand-off position logic.

## Open questions for the owner

1. OK with a Play-services build flavour for casting (F-Droid build
   without it)?
2. Start with the Default Media Receiver only, accepting that some live
   channels won't cast, or invest in a custom receiver early?
3. Should casting be admin-only or available to every profile (parental
   locks still apply to what's picked)?

## Milestones

1. Build flavours + Cast SDK wiring, device discovery, Cast button.
2. Cast a movie / episode (MP4) with hand-off and remote controls.
3. Live TV casting with HLS selection + friendly failure message.
4. Notification / lock-screen integration, polish, docs.
