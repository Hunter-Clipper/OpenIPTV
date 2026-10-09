# Changelog

What changed in each version of OpenIPTV, in plain English. Releases
and downloads are on the [Releases page](https://github.com/Hunter-Clipper/OpenIPTV/releases).

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
