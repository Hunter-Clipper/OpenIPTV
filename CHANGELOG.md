# Changelog

What changed in each version of OpenIPTV, in plain English. Releases
and downloads are on the [Releases page](https://github.com/Hunter-Clipper/OpenIPTV/releases).

## Unreleased (0.14.104)

**New**
- **Extra Guides.** Settings → Live TV → Extra Guides lets you add TV guide files (XMLTV) for channels your playlist has no guide for. They can be plain `.xml`, `.xml.gz` or zipped, as long as they unpack to XML. OpenIPTV does not provide guides; community sites publish them, and a web search for "XMLTV EPG" is a good place to start.
- **Smart matching.** A channel with no guide is matched by name to your guides. Your playlist's own guide always comes first (including channels it lists but forgot to link), then your extra guides in the order you set. Channels that already have a guide are never changed, and a doubtful match is skipped rather than guessed. US local stations are matched by call sign or by network and city, and never to a sub-channel or look-alike.
- **Change Guide.** Hold OK (TV) or long-press (phone) a channel → Change Guide to pick which guide it uses, search the guides, say "No guide for this channel", or go back to automatic. Your choice beats everything.
- **Review Guide Matches** (Extra Guides) lists every matched channel so a wrong one is easy to fix.
- Extra guides and the guides you picked by hand are included in backups.

**Fixed**
- **TV guide missing for some or all channels after a refresh.** When a provider answered a guide refresh with an empty guide (busy or rate-limited), OpenIPTV treated it as a success and cleared out part of the guide it already had. It now keeps your current guide and says the provider sent an empty one.
- **Stations listed more than once** (for example HD and SD versions of the same channel) now all get the guide. Before, only the first one did.

## 0.14.103 — 2026-11-11

**New**
- **Hide a single channel.** Hold OK (TV) or long-press (phone) a channel → Hide Channel. It disappears from Live TV, the guide, channel switching, search and Android Auto for that profile. Settings → Live TV → Hidden Channels brings channels back, one at a time or all at once.
- **Rename a channel.** Hold OK or long-press a channel → Rename Channel. The new name shows everywhere the channel is listed, in the player and on the lock screen or car display; the original name is still used for search. "Use the Original Name" undoes it.
- **Choose which categories are shown.** Settings → Live TV has switches for Favorites, Recently Watched and (TV guide) All Channels.
- **TV guide display options.** Settings → Live TV can turn channel names off in the guide, switch the two-line channel names off, allow two-line programme titles, and turn off the highlight on the channel that is playing.
- **Text Size.** Settings → Appearance → Text Size makes all text in the app Small, Default, Large or Extra large, on top of your device's own text size setting.
- **Player Transparency.** Settings → Appearance → Player Transparency sets how see-through the player's menus, channel list and controls backdrop are: Solid, Default, See-through or Very see-through.
- **Guide Data** (Settings → Advanced → Guide Data). Choose how many days of TV guide are kept (1 to 14, default 5), turn off storing programme descriptions to save space, see when each playlist's guide last updated and how many programmes it holds (or what went wrong), and clear the stored guide.
- **Start on Boot and Start on Wake (TV).** Settings → Playback has two new switches that open OpenIPTV by itself when the TV starts or wakes from sleep. Android needs "Display over other apps" allowed for OpenIPTV first; the app takes you to that screen. On boot the app opens about 12 seconds after the TV's home screen appears, so the home screen doesn't cover it.

**Improved**
- A new **Live TV** group in Settings holds everything about channels: sort order, hidden categories and channels, the category switches, and the guide options. Content Sort Order, Hidden Categories and Reset Category Names and Order moved there from Playback and Appearance.
- Holding a channel on a phone now buzzes once, not twice.
- The Reset Category Names and Order question now starts on Cancel, so a stray OK press doesn't reset anything.
- On TV, choice lists (Text Size, Skip Buttons and so on) now start on your current choice.
- Guide data: the guide's size is now trimmed to your "days to keep" choice at every refresh, and the Last update numbers refresh when a refresh finishes while the page is open.

## 0.14.100 — 2026-11-10

**New**
- **Stream details.** The quality chip in the player now also shows the picture size, frame rate and sound format, for example `HD · 1280×720 · 60 FPS · STEREO`. Each detail stays on the chip once it is known, instead of dropping in and out. The sound is named too (for example `AC3 5.1`, `AAC STEREO`), and the frame rate is also worked out on TVs that play on the fast tunneled path. The player menu has a Stream details switch (Show / Hide).
- **Audio delay.** If the sound doesn't line up with the picture, the player menu's Audio delay moves it earlier or later, from 0.5 seconds early to 1 second late. The choice is kept and included in backups. While a delay is set, surround sound passthrough and tunneled playback are switched off for that stream, because they can't be shifted; setting it back to None restores them.
- **Match Frame Rate with every stream.** It only worked for streams that announce their frame rate, which most live channels do not. It now uses the measured rate too, including on the fast tunneled path (the screen follows within about 1 to 2 seconds, measured from the picture's own timestamps).
- **Safer sound.** If surround passthrough or the audio delay ever stops the sound from starting (or the TV rejects it), the player now switches that feature off by itself, keeps playing with normal sound and shows a short message saying so.
- **Tidier settings.** Playback now only holds what plays (last channel on start, ask to start over, picture-in-picture, media notification, video in the car). The skip, controls-timeout and seek-key choices have their own Player group, and Content Sort Order moved to Appearance. Power User Tools is ordered by topic: network, picture and sound, then memory and storage. The Continue Watching switch is gone, since it did nothing (watch progress is always remembered).
- **Remote Seek Keys.** Settings → Player → Remote Seek Keys chooses what skips back and forward in catch-up and movies while the controls are hidden: the rewind / forward keys (always on), the Left / Right arrows, or the Up / Down arrows. It uses the Skip Buttons size, shows the controls briefly after each jump, and never jumps before the start.

## 0.14.99 — 2026-11-10

**New**
- **Open Last Channel on Start.** Settings → Playback has a new switch. When it is on, the app opens straight on the live channel you watched last instead of Live TV. It skips channels in hidden or locked categories, and does nothing when there is no history.
- **Skip Buttons.** Settings → Playback → Skip Buttons sets how far the back and forward buttons jump in the player: 5, 10 or 30 seconds. The icons match your choice.
- **Hide Player Controls After.** Settings → Playback lets you choose how long the player's controls stay on screen: 3, 4, 6, 8 or 12 seconds.
- All three are included in backups.

**Improved**
- Multi-view uses less memory on TVs: extra tiles now keep a few seconds of live buffer instead of up to 50, and a tile you aren't listening to no longer decodes its sound at all.
- Multi-view: the tiles you aren't listening to are no longer dimmed, and the little speaker icon is gone. The white box around a tile already shows which channel has the sound.

**Fixed**
- On some TV starts a channel could play sound with a black picture (the app and the TV's video layer disagreed about whether the layer was on). The app now waits for the TV side to be ready before deciding, and the picture only goes to the layer once both agree. Restarting the app used to be the only cure.

## 0.14.98 — 2026-11-07

**New**
- **Full-resolution pictures.** Posters, channel logos and backdrops now show in full resolution by default, for sharper artwork on every screen. If the app ever feels slow or restarts on a TV or phone with little memory, Settings → Advanced → Power User Tools → **Pictures** turns it off, and pictures go back to the lighter size. It takes effect straight away and is included in backups.

**Fixed**
- In the full-screen player, a favorited channel's star button no longer gets a coloured circle that looked like it had focus. Only the star changes now: filled for a favorite, outline when not.
- Some movies would never start and kept saying "Reconnecting…", even though other apps played them fine. Certain providers take 10–20 seconds to start a movie, and OpenIPTV gave up after 8 seconds and started over each time. Movies and episodes now get up to 45 seconds to show their first picture; live channels still reconnect quickly.

## 0.14.96 — 2026-11-06

**New**
- On TVs the main picture now plays on a real video layer, the way TV players do it. Motion is smoother, channel changes are quicker and cleaner (no flash of the old picture, no black gap), and the guide's playing preview now zooms smoothly to full screen and back, corners and all. The controls wait until the picture has finished growing. Settings → Advanced → Power User Tools → **Video layer** (Automatic / On / Off) lets you turn it off if the picture is ever wrong; it takes effect when the app restarts.
- **Tunneled playback** now works on TVs that support it. Automatic uses it on the Chromecast with Google TV (checked there), other TVs can try On. It is for live channels, pauses by itself during Multi-view, and still switches itself off and tells you if it ever fails.

**Improved**
- Everything defaults to Automatic: Video layer, Tunneled playback, Surround sound passthrough and Graphics mode all choose what suits your TV on their own.

**Fixed**
- Changing channel in the guide's preview no longer restarts the picture several times.
- Changing channel while tunneled no longer trips a decoder error when the size or format changes.

## 0.14.79 — 2026-11-06

**Fixed**
- Fixed some TVs showing no video during Tunneled playback. If a TV can't show it, OpenIPTV now switches it off by itself and tells you.

## 0.14.78 — 2026-11-06

**New**
- On TVs: Settings → Advanced → Power User Tools now has **Surround sound passthrough** and **Tunneled playback**, each Automatic / On / Off. Passthrough sends Dolby and DTS sound untouched to a soundbar or receiver that can decode it; Automatic uses it when your sound system says it can. Tunneled playback is experimental and for live channels only. Both pause by themselves while Multi-view is on, and if either one doesn't work on your TV, you are told and its setting is turned Off. Both start on Automatic for everyone, new installs and updates alike.

**Improved**
- Match Frame Rate has moved from Settings → Playback to Settings → Advanced → Power User Tools. Your choice is kept.
- Anonymous Reports now says plainly that reports are also sent when the app freezes, and how often they are sent.

## 0.14.77 — 2026-11-06

**New**
- On TVs: Settings → Advanced → Power User Tools → **Graphics mode**: if the picture looks torn (a line across it) or jittery on fast motion, try Compatible. Automatic switches it on for Mi TV (Amlogic S7D) televisions, where this was measured and fixed; other devices keep the standard mode. Takes effect when the app restarts, which it offers to do for you.

**Fixed**
- Anonymous crash reports now also cover the app freezing (Android's "app isn't responding" box) and crashes deep inside the system's video code. Before, only ordinary app errors were noticed, so a freeze that forced the app to close was never reported. If you turned reports on, these are sent too.
- Anonymous crash reports are now sent as soon as they are noticed instead of waiting up to a day.
- Tearing and jitter on Mi TV (Amlogic S7D) televisions during fast motion — see Graphics mode above.
- Anonymous crash reports no longer include things that aren't crashes: a logo or poster that can't be loaded, or a network hiccup such as a provider being down. Only real app crashes are reported now.

## 0.14.65 — 2026-11-04

**Fixed**
- Multi-view with providers that allow several connections: extra channels no longer die off one by one. Some providers tell connections apart by the device's name, so channels on one phone looked like a single connection and the others were dropped. Each channel now introduces itself separately.
- Multi-view: moving the sound to another channel could leave a different channel paused for good. Only one player now holds the sound; the others are just muted.

**New**
- Settings → Advanced → Power User Tools → **User agent**: choose the name the player gives your provider, for providers that only accept a particular one. Leave it empty to use OpenIPTV's own. It is included in backups.

**Improved**
- Live channels from providers that cut the stream every minute or so now carry straight on, with no short buffering pause at each cut.
- The player now introduces itself as OpenIPTV (with its version and your device) instead of a generic Android name, so your provider can tell your devices apart.

## 0.14.64 — 2026-11-04

**New**
- Search now looks inside the TV guide too. Search for a show (say "NFL Football") and you get **On now**, **Coming up** and **Earlier** rows, with the channel, the time and a progress bar for what is airing. Pick one to play it; earlier shows play from catch-up on channels that keep it.
- On channels with catch-up, opening a show that is already underway asks whether to **start from the beginning** or **watch live**. It works from search, the guide and the channel list, and you can turn it off in Settings → Playback → Ask to Start Over.

**Fixed**
- TV guide: the "Start from the beginning / Watch live" question no longer makes the menu and the category column suddenly expand behind it.
- TV guide: when a catch-up show playing in the preview reaches its end (for example at the top of the hour), it now carries on with the next show (or live, if that has only just begun) instead of stopping on an endless spinner.

**Improved**
- TV guide: pressing Back out of a catch-up show no longer stops it. It keeps playing in the guide's preview, like live channels do, until you pick another channel.
- TV guide: **hold Back** to return to the full-screen player of whatever is playing in the preview, live or catch-up.
- The catch-up (history) icon now shows next to the channel name on TV, in the guide and in search results, as it already did on phones.
- Search results for channels now show what is on right now under each channel, not only when the show was the reason it matched.

## 0.14.61 — 2026-11-03

**Improved**
- TV: one cleaner focus look everywhere. The white outline is gone; whatever you have selected now gets a soft accent-coloured highlight, like the left menu always had, and small items grow a little. It covers menus and settings rows, the guide, poster and channel cards (the highlight sits behind the picture and title and the title turns bold), round buttons (back, favourite, layout, the small ⓘ and refresh icons), the Play button, dialog buttons, profile tiles and text fields. The video player's buttons keep their white highlight so they stay visible over video.
- TV: "selected" and "focused" no longer look alike. The chosen category, the channel that is playing and the chosen avatar are marked with accent text, a thin bar or an outline, while the highlight fill means "this is where the remote is".
- TV guide: the channel that is playing is marked in the list (accent name, a thin bar and a small sound icon), so you can tell which one it is.
- TV: filled buttons (Play, Add Playlist, Save…) turn a clearly lighter shade when selected, and the highlight on your picture and name in Settings → Profile is a compact pill.
- TV: Settings → Profile now starts on your picture and name (one target) instead of a tiny edit badge, and the back arrow, ⓘ icons and episode rows have a clear highlight.

## 0.14.60 — 2026-11-03

**Improved**
- TV guide: the layout now gives the programme grid room in steps. On the left menu, everything is full size; in the category list, the left menu shrinks to small icons; in the guide grid, the categories shrink too. The change glides smoothly instead of snapping.
- TV: poster and channel cards no longer glow in the accent colour when focused (the white outline and the grow effect stay), and focusing them is smoother on slower TVs. Movie and series pages scroll more smoothly when there is no backdrop.
- TV: the left menu's focused icon no longer has a glow around it; the soft highlight pill is enough.
- Screen readers: each Multi-view tile now announces its channel name and whether it is the one you are hearing.
- The next-episode countdown ring is a little bigger so its number is readable.
- Screen readers: the full-screen video area is now announced ("Video, double tap to show or hide the playback controls") instead of being an unnamed control.
- Text fields have a clearer edge, so they are easy to spot against the dark background (name, playlist, PIN, search and dialogs). Setup cards also press in a touch more gently.
- Wording that fits both phones and TVs: hints now say "select" instead of "tap" (Profiles, PIN, VPN, update and car-video steps), since a remote doesn't tap.
- "Remove animations" now covers the whole app, not just screen changes: focus highlights, posters growing on focus, the player's controls fading, the TV guide column, scrolling to a focused item and the setup steps all switch instantly, and long names stay shortened instead of scrolling.

**Fixes**
- Updates: if GitHub can't be reached and the backup download copy is an older build than the release, the app now skips it instead of trying to install it (which would fail).
- Turning database encryption on or off told you the app would restart, but it just closed. The message now says it will close and to open it again.

## 0.14.53 — 2026-11-03

**Improved**
- Text on coloured buttons and badges is now readable on every accent colour. White labels were too faint on all six accents (Orange, Green and Teal were close to unreadable); they now switch to dark where white would fail.
- Secondary (grey) text is a little lighter, so hints and captions stay readable on filled fields and chips.
- If your device is set to remove animations, OpenIPTV now follows it: no screen-slide transitions, and the looping glow and shimmer effects hold still.
- Smaller text raised to a readable minimum: the LIVE badge, programme times in channel rows and rails.
- Clearer wording: "Couldn't load this" and "That didn't work" instead of "Something went wrong", "Enter a name." instead of "Please enter a name.", and refresh messages say "playlists refreshed".

**Fixes**
- TV: the one-time "Help improve OpenIPTV?" question now takes focus when it opens. Before, neither button could be selected with the remote until you pressed Back, because the Live TV guide behind it grabbed focus as it finished loading.

## 0.14.51 — 2026-11-03

**New**
- Optional anonymous crash reports, off unless you turn them on: if the app crashes, it can send a short report with the app version, your device model and where in the code it went wrong. Never your playlists, logins, links, channel names or what you watch, and it can't be tied to you. People who update are asked once, new installs are asked once in setup, and Settings → Advanced → Anonymous Reports changes it and shows exactly what is sent (#150).
- Settings → Playback → Match Frame Rate: switches your screen to a refresh rate that suits the video (for example 24 Hz for films) while you watch, then puts it back. Off by default; needs a screen that offers that rate, and some TVs go black for a moment when switching (#149).

**Improved**
- TV guide: the category column shrinks to just its icons while you are in the guide, giving the programme grid more room. Move Left to bring the names back (#148).

**Fixes**
- Typing a server address in Add Playlist (or Edit Playlist) no longer fills in the password box from your phone's password manager. These fields now opt out of autofill (#147).

## 0.14.47 — 2026-11-02

**New**
- Live stream format per Xtream playlist (Edit Playlist): Automatic, TS or HLS. Automatic follows what your provider allows, usually TS (#136).
- Rename Live TV categories: hold OK (long-press on phone) on a category and pick Rename Category. Only changes how it looks for your profile; clean-up skips renamed categories (#59).
- Reorder Live TV categories: hold OK on a category and pick Move Up or Move Down. Works in Live TV, the TV guide and the player's channel panel (#58).
- Settings: Reset Category Names and Order puts the provider's names and order back.

**Improved**
- Clean Up Names now uses one standard for every playlist, whatever its naming style (`US| NAME HD`, `USA: NAME [1080p]`, `Name (1080p) [Not 24/7]`, `EN - Title (2022)`): provider tags are removed from the front, the middle and the end; country or language moves to the end (`ABC Network (USA)`, English is dropped, `(United Kingdom)` becomes `(UK)`); quality tags (HD, FHD, 1080p, 576i, H265…) are dropped while 4K or UHD becomes a short `4K` at the end; `24/7` and `Events` stay in place; `[Geo-blocked]` is kept. Live sports event names lose their slot prefix and repeated team names and end with `Ended`, `Next` or `Not started` where the provider says so. Names it doesn't recognise, and real titles such as `Mission: Impossible`, are left alone. Movie and series genres follow, since they use the category names.
- Images load faster and stay loaded: logos, posters and backdrops now all share one bigger image cache (3,000 images, up from a library default of 200 for several screens), so scrolling back through a large playlist no longer downloads the same logos again, and twice as many images download at the same time on slow connections (#133, #134).
- Detail-page backdrops are now decoded at your screen's size instead of the picture's full size, which saves a lot of memory on small TVs (#133, #134).
- TV: a category name that is too long for its box now scrolls sideways instead of being cut off with dots, in the TV guide's category list (while the row is focused) and in the player's channel panel.
- Skip Database Encryption moved into Power User Tools, under a new Database heading, so a stray OK press in the main Settings list can't flip it. Turning encryption back on now asks first too.

**Fixes**
- Back now closes a dialog first, even on a Settings sub-page. Before, pressing Back with a dialog open (for example Change PIN, Edit Profile or New Profile) went back a page behind it and left the dialog hanging open on top of the wrong screen.
- TV guide: focus could get stuck in the guide, with Left and Back doing nothing, when the category being shown was scrolled out of view in the category list. The list now scrolls to it first, and falls back to any visible category so you can always get out.
- TV guide: the focused channel now stays centred in the list and glides smoothly while you hold Up or Down, instead of pinning to the bottom and jerking (#135).
- Stream type is now decided by the link's file type only, not by words in the server name, so a server like `x.tsc.com` no longer makes a stream play as the wrong kind (#139).
- A stream that was already playing no longer gets restarted as HLS after a brief hiccup; the HLS retry is only for streams that never showed a picture, and live channels rejoin at the live edge (#139).
- If the player fails to start once, the next try now works instead of failing until the app is restarted (#139).
- Switching channels no longer briefly stretches the previous channel's last frame into the new picture's shape (#139).
- Player cleanup: listeners and video surfaces are released properly when a player closes, and captions stay off after the buffer setting changes (#139).
- 24/7 movie channels in playlists with no stream-type hint now stay in Live TV instead of landing in Movies.
- Locked channels no longer show their logo in search results.
- Change PIN / Set PIN fields now match the unlock prompt: centred, large dots, with a normal-sized hint.
- Locked content (parental, adult or manually locked) never goes into Continue Watching or Recently Watched, even after unlocking with the admin PIN, and its resume position isn't saved. Existing history entries from locked categories are hidden.
- Hidden Categories (Settings) now shows the same names as Live TV (cleaned up or your own renames), and the built-in "All Channels" row reads properly instead of showing a hidden character.
- Power User Tools: the first row is now focused when the page opens on a TV, so Up and Down start from the top.

## 0.14.33 — 2026-10-27

**Performance**
- Increased EPG write batch size from 1000 to 5000 programmes per batch, reducing WAL lock contention and write time on low-end TV devices (#131).

## 0.14.32 — 2026-10-26

**Features**
- Skip Database Encryption setting (Power User → Advanced): allows slow TV devices to use plain SQLite instead of SQLCipher, eliminating encryption overhead. Includes encrypted→plaintext migration, confirmation dialog with security warning, and auto-restart on toggle (#127).

## 0.14.31 — 2026-10-26

**Fixes**
- Background refresh error handling: wraps refresh in try/catch, returns false on failure for WorkManager retry (#117).
- Faster image loading: custom cache manager with 24 concurrent connections, disk cache dimensions, increased ImageCache, and optimized cached resolution (#118).
- On-screen player title now respects Clean Names preference (#75).
- Reduced unnecessary rebuilds: ref.read instead of ref.watch for playback service singletons (#77).
- autoDispose on search query and content details providers to prevent memory leaks (#78).
- Accessibility semantics added to StarButton, QualityChip, and ToggleTile (#81).
- Added error logging to background EPG fetch callbacks (#125).
- Covering indexes for watch_progress, programmes, and channels for faster reads (#126, #128).

## 0.14.30 — 2026-10-23

**Fixes**
- Progress bars in Live TV channel list and TV guide now update in real time (#70).
- TV focus improvements: player option row and season chips now navigable via D-pad (#76).
- TV guide back navigation: fallback focus so users are never stranded (#113).
- Background refresh error handling: wraps refresh in try/catch, returns false on failure for WorkManager retry (#117).
- Faster image loading: custom cache manager with 24 concurrent connections, disk cache dimensions, increased ImageCache, and optimized cached resolution (#118).
- On-screen player title now respects Clean Names preference (#75).
- Reduced unnecessary rebuilds: ref.read instead of ref.watch for playback service singletons (#77).
- autoDispose on search query and content details providers to prevent memory leaks (#78).
- Accessibility semantics added to StarButton, QualityChip, and ToggleTile (#81).

**Features**
- Live TV player: Live button is now always focusable and clickable to force a re-sync to the live edge.

## 0.14.29 — 2026-10-21

**Fixes**
- Unsafe casts in Xtream episode parsing no longer cause crashes on non-compliant providers (#69).
- EPG refresh now uses bulk upserts and a single transaction, significantly reducing refresh time (#72).
- "More Like This" section no longer shows stale data after a profile switch (#71).
- "More Like This" section bottom padding now dynamically accounts for system nav bar to prevent text cutoff.
- Profile service no longer snapshots prefs at construction time, preventing stale null-prefs instances (#74).
- Prevent NaN progress bar when programme duration is zero (#80).
- Fixed SQLite 999-variable limit in Continue Watching queries (#68).
- Fixed upsertProgrammes crash (DoUpdate cast was wrong) that broke EPG refresh (#96).
- Escaped LIKE wildcards in search and genre queries (#80).
- Safe cast in getShortEpg for Up Next overlay (#80).
- Extracted year from releaseDate in series parser (#80).
- Set tvgName to null for Xtream channels (no tvg_name field) (#80).

**Features**
- Accent color is now profile-specific and included in backups.
- Added Up Next section to series detail page (#108).

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
