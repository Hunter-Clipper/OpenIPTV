# Changelog

What changed in each version of OpenIPTV, in plain English. Releases
and downloads are on the [Releases page](https://github.com/Hunter-Clipper/OpenIPTV/releases).

## 0.14.29 — 2026-10-21

**Fixes**
- Unsafe casts in Xtream episode parsing no longer cause crashes on non-compliant providers (#69).
- EPG refresh now uses bulk upserts and a single transaction, significantly reducing refresh time (#72).
- "More Like This" section no longer shows stale data after a profile switch (#71).
- "More Like This" section bottom padding now dynamically accounts for system nav bar to prevent text cutoff.

## 0.14.28 — 2026-10-21

**Fixes**
- Deleting a playlist from Settings now shows a spinner dialog while the database is cleaned up, so the app no longer appears frozen on large playlists (#91).
- Channel switcher no longer crashes if category is null before first build completes (#83).
- Up Next banner no longer fires onPlay after widget is unmounted (#82).

## 0.14.27 — 2026-10-21

**Fixes**
- M3U playlists now parse in a streaming fashion (line-by-line via `LineSplitter` over a byte stream) instead of loading the entire file into memory as a `List<String>`. Eliminates the OOM risk on TV devices when loading large playlists (~18k channels) (#79).
- HTTP M3U downloads now use streaming HTTP (`StreamedResponse`) so bytes are decoded and discarded as they arrive, rather than buffering the full response body (#79).

## 0.14.26 — 2026-10-21

**Fixes**
- When PiP is enabled but a transient overlay (channel switcher or multi-view) is open, pressing Home now stops playback instead of letting the stream continue silently in the background. PiP is correctly suppressed while the overlay is open; when the overlay closes, PiP re-becomes available.
- Multi-view: when Home is pressed with PiP enabled and the multi-view overlay is open, all streams (main + tiles) are killed and no background playback occurs.

**Fixes**
- Picture-in-Picture no longer starts from non-player screens (settings, guide, channel list). PiP is now only offered when the full-screen player is active and playback is running (#88).
- PiP now defaults to off on TV (where the screen is the TV itself), while remaining on for phones and tablets. Users can still enable it in Settings → Picture-in-Picture.

## 0.14.23 — 2026-10-21

**Fixes**
- Memory leaks: CastService, UpdateService, NowPlayingHandler, and EpgService now dispose their stream subscriptions when the service is destroyed, preventing leaks during long playback sessions (#73).
- Backup/restore now includes all 10 previously missing user preferences, so no settings are silently dropped when backing up or restoring a profile (#67).

**Features**
- All Channels category can now be hidden or shown in Settings → Live TV → Categories, keeping the channel list focused (#60).

## 0.14.22 — 2026-10-20

**Fixes**
- Channel IDs for M3U playlists now use deterministic SHA-256 hashes instead of `String.hashCode`, preventing data loss (orphaned watch history and favorites) on Dart SDK upgrades. Includes schema 11 migration to re-key existing data.

## 0.14.21 — 2026-10-20

**Fixes**
- Hotfix: corrected the app version bump so the auto-updater no longer loops on v0.14.20 (the previous release shipped without a matching version bump).
- Download now falls back to the Cloudflare R2 mirror (custom domain + r2.dev) when GitHub is unavailable.

## 0.14.20 — 2026-10-20

**Fixes**
- TV navigation: D-pad right from the nav rail focuses the category column; Back from the guide lands on the category column, then the rail; Back on Movies/Series/Search/Settings focuses the rail first. Selecting the Live TV tab focuses the currently shown category.

## 0.14.19 — 2026-10-20

**Playlist & guide reliability**
- M3U playlists with an empty guide URL now adopt an embedded `url-tvg` (matching Xtream behavior), so guides that were silently skipped now load.
- Live TV pull-to-refresh no longer fires the guide fetch against a stale source — a newly discovered guide URL is used immediately.
- Guide connection failures now report a playlist-specific message ("may not have a guide") instead of a generic internet error.

## 0.14.18 — 2026-10-19

**Fixes**
- Fixed EPG guide failing instantly when the server errors before sending any data (stall timeout handler crashed with LateInitializationError).

## 0.14.17 — 2026-10-19

**Fixes**
- "Refresh Everything" now shows the same plain-English error messages as the individual refresh buttons (timeouts, auth failures, network errors, server errors).

## 0.14.16 — 2026-10-19

**Fixes**
- Fixed the Settings page getting stuck on TV — the remote back button now navigates directly to Live TV instead of stopping at the rail first.

**Playlist & guide reliability**
- Added stall timeouts to EPG guide fetching — a slow but progressing feed keeps going; only a truly stalled connection times out.
- A failed guide refresh now keeps the previous guide intact instead of clearing it.
- Added overall timeouts to M3U and Xtream playlist refreshes (3 minutes) so a hung operation fails instead of spinning forever.
- Added plain-English error messages for timeouts, auth failures, network errors, and server errors — both for playlists and TV guides.

## 0.14.15 — 2026-10-19

**Code quality**
- Extracted shared genre utilities (`filterByGenre`, `buildGenreNames`, `buildGenreCounts`) — removes duplication between Movies and Series screens.
- Extracted shared genre actions (`tapGenre`, `hideGenre`) — both screens now use the same navigation and hide-genre flow.
- Extracted shared snackbar utility — consistent snackbar behavior across Settings and Power User screens.
- Removed dead code and stale TODO comments.

## 0.14.14 — 2026-10-16

**Player**
- New **Clock** option in the player's playback settings: choose "Always on" to keep the time of day in the top corner while you watch full screen, even when the controls are hidden. "With controls" (the default) keeps it the way it was on TV.

**TV guide**
- Watching a past programme from catch-up, pressing Go live, then Back now returns to the guide with the channel still playing in the preview pane. Before, playback stopped. This works whether you opened catch-up from the guide or from the programme list in the player.

**Behind the scenes**
- Once Go live switches a catch-up programme to the live channel, the player now treats it as live everywhere: reconnecting after a stall goes back to the live channel, and casting sends it as live.

## 0.14.8 — 2026-10-14

**TV guide**
- Long channel names and programme titles no longer stay cut off. When a channel or programme is highlighted, its text slides sideways to show the rest, pauses, and starts again. The programme title and details at the top of the guide do the same. Text that already fits doesn't move.

**Playback stops when you leave**
- Press Home with Picture in Picture turned off and whatever is playing now stops: the full-screen player, the TV guide preview and multi-view (all tiles). Casting to another device keeps going. With Picture in Picture on, Home works as before.
- Close the Picture in Picture window (the X, or swipe it away) and the stream now stops for good. Before, it could quietly start again behind other apps. Expanding the window back to the app still keeps playing.
- If another app takes the sound (YouTube starting a video, a phone call), OpenIPTV now stays paused instead of starting again by itself when that app lets go. Press play to carry on.

**Behind the scenes**
- When the Picture in Picture window closes, every stream is stopped at the source and the player's automatic reconnect is switched off.

## 0.14.0 — 2026-10-13

**A TV guide on TVs**
- On a TV, Live TV is now a full programme guide: your categories down the left, what's on (with its time and description) at the top, and every channel's programmes on a timeline below — with channel logos, and a line marking the time now.
- Move through categories with the remote and the guide follows. Favorites, Recently Watched and All Channels come first; locked categories ask for the PIN.
- Hold OK on a channel for its options.
- **Preview:** OK on a channel plays it in the picture at the top, so you can keep browsing while it plays. Press OK again on it to watch full screen — it carries on without restarting — and Back brings you back to the guide with it still playing. If a channel can't play, the picture says so instead of staying black.
- OK on an earlier programme plays it from catch-up where the channel has it; anywhere else, OK plays the channel live.
- Up and Down keep your place in time, so you move straight to what's on the next channel.
- In Recently Watched, hold OK on a channel to remove it.
- Phones and tablets keep Live TV as it was.

**Fixes**
- In the player, Back now hides the controls when they're showing; press Back again to leave.

## 0.13.2 — 2026-10-12

**Fixes**
- On a TV, holding OK on a channel to open its options could pick the first option by itself (for example, removing the channel from Recently Watched). Holding OK now only opens the options.

## 0.13.1 — 2026-10-12

**Fixes**
- In multi-view, some channels could keep loading forever in an added tile while playing fine full screen. Added channels now open every kind of stream the same way the full-screen player does.
- In multi-view, channel names on the tiles and in the options now follow **Clean Up Names**, like the rest of the app.

**Behind the scenes**
- Tidier multi-view code: the tiles redraw less often (easier on TV sticks) and the sound switches between channels with less work.

## 0.13.0 — 2026-10-12

**Multi-view — watch several channels at once**
- While watching a live channel, tap **Add a channel** (next to the channel list) and pick another. The screen splits so you can watch both — and you can keep adding more.
- The layout follows how many channels you're watching: two side by side, three as one big with two smaller, four in a grid, and so on. Choose **Equal grid** or **One big** any time.
- Sound comes from the channel you highlight (move with the remote, or tap it on a phone); the others stay quiet and slightly dimmed, and a speaker shows which one you're hearing.
- Press OK (or tap the highlighted channel) for its options: **Full screen**, **Swap channel**, **Add a channel**, **Layout** and **Remove**.
- **Back** keeps the highlighted channel playing full screen.
- Works with every playlist. If a provider won't allow another stream, or a channel isn't available, that tile says so in plain English and the others keep playing.
- Phones show multi-view sideways, like the full-screen player.

**Fixes**
- Picking a channel from the channel list in the player could close the player and drop you back to the list. It now switches channel as it should.
- Opening OpenIPTV from the home screen now checks for updates again. Before, the check only ran when the app had been fully closed, so a new version could go unnoticed. It checks at most every 15 minutes, and never interrupts a video you're watching.

## 0.12.2 — 2026-10-12

**Settings is now a tab**
- Settings has moved from the small gear in the top corner to the menu with Live TV, Movies, Series and Search — at the bottom on phones and tablets, on the left on TVs.

**Typing on a TV**
- The on-screen keyboard now sits in a full-width tray that slides up smoothly, instead of cutting the screen off on both sides of it. The menu on the left stays in place.
- The field you're typing in, with its label, is kept in view just above the keyboard.
- A blinking cursor now shows where you're typing.
- **Next** on the keyboard goes straight to the next field with the keyboard still open — no pressing OK on every field.
- Search: pressing the keyboard's Search key takes you straight to the first result.
- Change PIN no longer shows a "0/8" counter inside the highlight, and the backup password box is where the remote starts (one press used to export an unprotected backup). Entering a protected backup's password opens the keyboard straight away.
- The Playlists panel now starts with the remote on Add Playlist instead of an off-screen row.
- Edit Playlist starts with the remote on the first box (press OK to type).
- In small windows (Change PIN, a new profile), the box you're typing in lines up neatly at the top — no more half-cut boxes above or below it.
- Back on the add-playlist screens goes one step back instead of closing them, and the back arrow there is no longer cut off.

**Storage**
- OpenIPTV takes up less space. Every refresh left unused space inside its database that was never given back to your device. Now it's handed back after each refresh, and the first time you open this version OpenIPTV tidies up its database once (about half a minute on a TV — one TV went from 203 MB to 108 MB).
- If your device is nearly full, OpenIPTV clears its TV guide first to make room for the tidy-up, then downloads the guide again. No reinstall needed.
- Saving a TV guide does half the work it used to: each programme is saved once instead of twice, and guide entries for channels you don't have are no longer stored.
- Removing a playlist now also removes its TV guide straight away.

## 0.12.0 — 2026-10-11

**Power User Update**

**Power User Tools** — Settings → Advanced, at the very bottom (admin profiles)
- **Network info:** see how your device is connected — Wi-Fi or Ethernet, its IP address, DNS servers and whether a VPN is on. Tap **Check** to see the public IP address your provider sees. Handy when a provider has trouble reaching you.
- **Built-in VPN:** import a WireGuard (`.conf`) or OpenVPN (`.ovpn`) profile from your VPN provider, then connect with one tap. Choose **Only OpenIPTV** (other apps keep your normal connection) or **Whole device** (everything except Android Auto's link to your car). It can connect automatically when OpenIPTV opens. The first time, Android asks to allow a VPN connection — that's normal.
- **Speed test:** how fast video arrives from your provider, and a general internet test, each with a plain-English verdict (SD, HD, 4K).
- **Playback buffer:** **Fast start** (as before), **Balanced** or **Smooth** — a bigger reserve rides out a shaky connection but takes longer to start.
- Works with a TV remote, and nothing is sent anywhere unless you tap a button that says where it goes: **Check** asks api.ipify.org for your public IP address, and the general speed test downloads a file from speed.cloudflare.com.

**Watch in the car while parked** — Android Auto
- Pick a channel, movie or episode in OpenIPTV on the car screen, then open **Video** (the second OpenIPTV icon) to see the picture full screen. It shows what OpenIPTV is already playing, so there's no second connection to your provider.
- Made for when you're parked: cars that limit apps while driving close the picture, and the sound keeps playing.
- Needs a small add-on app (about 1 MB). Install it from **Settings → Playback → Video in the Car**. If it doesn't show up in the car, turn on "Unknown sources" in Android Auto's developer settings.

**Fixes**
- Your data is safer: if the phone or TV briefly fails to unlock OpenIPTV's encrypted storage at start-up, OpenIPTV now tries again instead of starting over empty.
- Restoring a backup, or changing the Auto-Refresh setting, no longer starts a second full download of every playlist in the background.
- Closing OpenIPTV (swiping it away from recent apps) now also turns off its built-in VPN. Pressing Home or listening in the car keeps it on.
- Android Auto: picking something on the car screen now always plays what you picked — before, it could switch back to what the phone had played first.
- Android Auto: if a channel freezes, the car reconnects by itself, and a title that can't play shows a short message instead of sitting at 0:00.

## 0.11.13 — 2026-10-09

**Unlock with your fingerprint or face**
- The admin can now use their fingerprint or face instead of typing the admin PIN: when opening a locked category or locked search result, turning off a Kids profile, or switching to the admin profile on "Who's watching?".
- It's off until you turn it on: **Settings → your profile → Security → Unlock with Fingerprint or Face**. Turning it on asks for the admin PIN first.
- The admin PIN always works too — tap **Use PIN** on the scan prompt, or just cancel it.
- If a new fingerprint or face is added to the device, it turns itself off and tells you why, so nobody else's fingerprint can unlock it without you knowing. Turn it back on in the same place.
- Other profiles still use their own PINs. Phones and tablets only (Android 11 and newer, with a fingerprint or face unlock set up); TVs keep the PIN.

## 0.11.8 — 2026-10-08

**Playlist refresh you can trust**
- If your provider has a problem partway through a refresh, your playlist now stays exactly as it was. Before, a refresh that failed halfway could leave a playlist with missing channels, movies or series until the next good refresh.
- Pulling down to refresh Live TV, Movies or Series now only refreshes the playlist you're browsing (or all of them when you browse "All playlists"), so it finishes much sooner. If a playlist can't be refreshed, you'll see a short message saying which one and why, and the others still refresh.
- When a provider's server is having trouble, the message now says so, instead of suggesting your playlist link is wrong.
- Refreshing or removing a playlist is much faster on TVs with large playlists.

**Playlists screen**
- "Playlist refreshed" and "refresh failed" messages now show inside the Playlists panel instead of hiding behind it.
- On TV, the remote's highlight stays on the playlist you're refreshing instead of jumping to another row.

The first time you open this version, it takes a few extra seconds to tidy up its database. This only happens once.

## 0.11.0 — 2026-10-08

**OpenIPTV in your car — Android Auto**
- Browse Live TV, Movies and Series on your car's screen and listen through the car's speakers.
- Play, pause, next and previous from the car display; your place in movies and episodes is saved as you listen.
- Search from the car, with parental controls and Kids profiles applied just like on your phone.
- Playback pauses instead of switching to your phone's speaker when headphones or the car disconnect.

Earlier versions are described in their release notes.
