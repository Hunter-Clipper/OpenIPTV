# TV guide with preview (Android TV)

Status: **released in v0.14.0** (2026-10-13, PR #54).

A user asked for a preview pane on TV. On TV, the Live TV tab becomes a
full programme guide: a column of categories, a preview with what's on at
the top, and a channel × time grid below. Phones and tablets are unchanged.

## Owner decisions (2026-10-13)

| Topic | Decision |
|---|---|
| Layout | **Full guide on TV**: nav rail · category column · top pane (preview + programme info) · channel × time grid. |
| Phones | Unchanged. |
| Preview video | **Always on** (owner, 2026-10-13: the setting that turned it on was removed). |
| OK | OK on a channel plays it **in the pane**; OK again on the channel already playing there opens it **full screen** — the same stream, no restart. Back from full screen returns to the guide with it still playing in the pane. No channel name over the preview picture. |

## Layout

```
┌rail┐┌ Categories ┐┌ [preview 16:9] │ Programme title          ┐
│    ││ Favorites  ││                │ 12:25 – 14:30 · Channel  │
│    ││ Recently   ││                │ Description…             │
│    ││ All        │├─────── 12:00 ──┼── 12:30 ──── 13:00 ───────┤
│    ││▶Cinema     ││ 13 [logo] Name │ Programme │ Programme     │
│    ││ Kids       ││ 14 [logo] Name │ Programme      │ Prog…    │
└────┘└────────────┘└──────────────────────────────────────────┘
```

- **Categories** follow Live TV's rules: Favorites and Recently Watched
  first (when not empty), then All channels, then every category in
  first-appearance (or A–Z) order. Hidden categories are left out, adult
  ones are left out on kids profiles, and parental-locked ones show a lock
  and ask for the PIN when opened. The active playlist applies, as
  everywhere.
- Moving through the column changes the grid after a short pause, so
  scrolling quickly doesn't reload on every step.
- **Rows:** the channel logo (same readable grey tile as
  Live TV) and name, then the programmes on a shared timeline with a "now"
  line. A channel with no guide data shows one plain "No guide information"
  cell, so it can still be focused and played.
- **Top pane:** the focused programme's title, time, channel and
  description; with preview on, the video sits on its left.

## Remote

- The channel's logo and name are a label, not a stop for the remote
  (owner, 2026-10-13): the programmes are what you move through. Right
  from the column lands on what's on now in the first row (or the
  programme you left there).
- Up/Down: channels (or categories in the column). Left/Right: through
  time; Left at the start of the timeline — or on a "No guide
  information" cell — goes back to the category column, and Left again to
  the nav rail.
- OK on any cell plays the channel live (see the preview rules above) —
  except an earlier programme on a channel with catch-up, which plays it
  from catch-up. (Stress test, 2026-10-13: OK doing nothing on later
  programmes felt broken.)
- Up/Down go to the cell in the next row at the same time: now, if the
  focused cell is airing, else the start of its visible part (Flutter's
  own search went by the cell's middle and jumped hours ahead from wide
  cells).
- Hold OK on any of a channel's cells: the usual channel options
  (favourite; in Recently Watched also "Remove from Recently Watched").
- Back: the app's usual TV Back (page → nav rail → …).

## How it works

- `lib/features/live_tv/tv_guide_screen.dart` is rewritten as the TV body
  of the Live TV tab (`ChannelListScreen` hands over on TV). The old
  full-screen guide route, its hidden "TV Guide" card and
  `kTvGuideEnabled` go away.
- Programmes load **per visible row** (`channel_id` + time window on the
  existing `idx_programmes_channel_time` index), never the whole window
  for every channel — the old guide's all-channel query would be far too
  heavy for a ~18,000-channel playlist on a TV stick.
- The preview plays on the app's **main player** (owner, 2026-10-13: going
  full screen must not restart the stream, and Back must leave it playing
  in the pane). OK again opens the full-screen player on the stream that's
  already playing (`continuePlaying`, `PlaybackService.adopt`); leaving it
  hands the stream back to the guide (`handBackTo`) instead of stopping
  it, also after a channel switch. One stream is open throughout, so plans
  with a single connection keep working. The preview stops when the guide
  is left (another tab, the app in the background). It has its own
  StreamWatchdog (reconnects a stuck stream; a dead one shows "This channel
  isn't available right now." / "Your provider didn't allow this
  stream."), and shows the channel logo with a spinner until the new
  stream's first frame (the texture otherwise still shows the last one).

## Testing

- Chromecast: main (full guide), iptv-org (no guide data, many dead
  streams), a playlist with locked/hidden categories, a kids profile.
- Speed: open All channels on main, scroll fast, switch categories fast.
- Preview: OK → plays in pane, OK again → full screen and the pane's
  connection is gone; Back from the player returns to the guide.
- Phone: Live TV unchanged.
