# Multi-view (issue #52)

Watch several live channels on one screen. The goal is that it stays out of
the way for people who never use it, and feels effortless for those who do.

## Owner decisions (2026-10-12)

| Topic | Decision |
|---|---|
| Starting it | From the live player: one more round button, **Add a channel**, next to the channel list. It opens the existing channel panel; picking a channel splits the screen. Nothing changes anywhere else in the app. |
| Layout | Automatic by the number of channels — 2 side by side, 3 = one big + two small, 4 = 2×2, then larger grids — plus a **Layout** choice between *equal grid* and *one big + small*. |
| Sound | Follows the highlighted tile; the others are muted. A small speaker badge marks the tile you hear. |
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
- Sound: every tile's volume is 0 except the highlighted one, and only that
  tile holds audio focus (so calls and navigation prompts still pause /
  duck what you hear). Moving the highlight moves both.
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
