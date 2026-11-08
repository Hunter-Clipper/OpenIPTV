# Multi-view (issue #52)

Status: **released in v0.13.0** (2026-10-12).

Watch several live channels on one screen. The goal is that it stays out of
the way for people who never use it, and feels effortless for those who do.

## Owner decisions (2026-10-12)

| Topic | Decision |
|---|---|
| Starting it | From the live player: one more round button, **Add a channel**, next to the channel list. It opens the existing channel panel; picking a channel splits the screen. Nothing changes anywhere else in the app. |
| Layout | Automatic by the number of channels — 2 side by side, 3 = one big + two small, 4 = 2×2, then larger grids — plus a **Layout** choice between *equal grid* and *one big + small*. |
| Sound | Follows the highlighted tile; the others are muted. The white focus box marks the tile you hear (no speaker badge, and the other tiles are not dimmed — owner, 2026-11-08). |
| Which playlists | **Every playlist.** No reading of the provider's connection limit. If a provider refuses another stream, that tile says so in plain English and the others keep playing. |
| How many | **No fixed cap.** If the device can't decode another stream, that tile says so. |
| A tile's options | OK / tap on the highlighted tile: **Full screen**, **Swap channel**, **Add a channel**, **Layout**, **Remove**. |
| Leaving | **Back** keeps the highlighted channel playing full screen (the others stop); Back again leaves the player as today. |
| Phones | Landscape only, like the full-screen player. |

## How it works

- The channel you were watching keeps playing in its tile — the app's
  main player stays as it is, so entering multi-view never interrupts it.
  Each added channel gets its own native player (the TV guide preview
  already runs a second one), rendered in its own texture.
- Sound: every tile's volume is 0 except the highlighted one. Only the
  app's main player ever holds audio focus (so calls and navigation prompts
  still pause / duck what you hear); the other tiles are audible by volume
  alone. (0.14.65: with several players asking for focus, a late request
  from one tile took it from the audible one and ExoPlayer paused that tile
  for good. A muted tile that still gets a focus loss resumes itself.)
- Every tile has its own stream watchdog: a frozen tile reconnects on its
  own; one that can't play shows a short message instead of a black box.
- Removing a tile (or leaving multi-view) stops its stream at once, so
  the provider frees the connection.
- Leaving multi-view with a tile other than the first highlighted: the
  main player switches to that channel and the others stop.

## TV (remote)

- D-pad moves the highlight between tiles (and the sound with it).
- OK on a tile opens its options; Back leaves multi-view.

## Phones

- Landscape. Tap a tile to hear it; tap the highlighted tile for its
  options. Back as above.

## Testing

- Owner's main playlist allows one connection, so testing uses iptv-org
  (public) and DrewLive.
- Phone (Pixel 9 Pro XL) and TV (Chromecast with Google TV): 2, 3, 4+
  tiles, sound switching, swap, remove, layout switch, Back, a refused
  stream, a frozen stream, leaving and re-entering.

## One connection per tile — user agents (0.14.65)

Found 2026-11-04 on the owner's provider (behind a CDN): **the provider
tells connections apart by IP address + user agent.** The app never set a
user agent, so Android's HTTP stack sent the same `Dalvik/2.1.0 (Linux; U;
Android …; <model> …)` string for every player on a device. A phone + a TV
showed as two connections (different models); three tiles on one phone
showed as one, and the others "slowly died".

- Every stream now sends `OpenIPTV/<version> (Android <release>; <model>;
  <install tag>)`. The install tag is 6 random hex characters created once
  per install (native prefs `openiptv_native`), so two devices of the same
  model on one network still differ.
- Each extra tile adds its own tag on the end (`… mv1`, `… mv2`).
- Settings → Advanced → Power User Tools → **User agent** replaces the base
  string (pref `user_agent`, in backups). Tiles still add their tag to it.
  `parseCustomUserAgent` refuses anything that can't go into an HTTP header.
- Only playback streams use it; catalog and guide downloads send Dart's
  default.

## Seamless reconnect for live `.ts` (0.14.65)

The same provider serves live `.ts` as ~60 s bursts: it pushes about a
minute of video in a few seconds and ends the response. The player used to
reconnect only when its buffer ran dry (1–2 s of buffering a minute, per
tile). For live channel links (`PlaybackService.isLiveTs`: `.ts` under
`/live/`) the native player now appends the same URL as the playlist's next
item once the current connection has ended and under 3.5 s of video is left,
so ExoPlayer moves on without a gap; played items are removed. The old
"ended → watchdog reconnects" path remains as the fallback. Catch-up, VOD and
HLS are untouched.

Logs (`adb logcat | grep OTV-http`): the user agent each player sends,
`closed … after Ns` for long connections, `next connection queued`, and HTTP
failures. URLs are never logged (they hold the login).
