# Privacy

OpenIPTV is a player. It has no ads, no accounts and no tracking, and it
collects nothing about you or what you watch. This page says exactly what the
app contacts and what leaves your device. Where it differs from the code,
the code wins; please open an issue if you spot a mismatch.

## What stays on your device

Your playlists, logins, favourites, watch history, profiles, PINs and
settings are stored only on your device. The database is encrypted. Backups
you export are files you choose where to keep; encrypt them with a password
when asked.

## Who the app contacts

| Who | When | What is sent |
|---|---|---|
| **Your playlist and guide providers** | Whenever you browse or play | The requests needed to load your playlist, guide and streams. This includes your login for Xtream providers and a player name (user agent) such as `OpenIPTV/<version> (Android <release>; <model>; <install tag>)`. You can change it in Settings → Advanced → Power User Tools. |
| **GitHub** (`github.com`, `api.github.com`) | Checking for updates, and downloading one | A normal web request for the latest release. Nothing about you or your playlists. |
| **Cloudflare-hosted mirror** of the releases | Only if GitHub can't be reached | A normal web request for the update file. |
| **api.ipify.org** | Only when you tap Check in Power User Tools → Network info | A normal web request. It answers with your public IP address, which is shown to you. |
| **speed.cloudflare.com** | Only when you tap the general speed test | A normal web request to download test data. |
| **Anonymous crash reports** (`openiptv-stats.hunter-clipper.workers.dev`) | Only if you turn them on | See below. |
| **Chromecast devices on your network** | When you use Cast | The stream address, so the receiver can play it. |

Each of these services sees your IP address, as any website does. OpenIPTV
does not add cookies, advertising IDs or device IDs to any of these requests.

## Anonymous crash reports (optional, off by default)

You are asked once. "No Thanks" counts as an answer and you are not asked
again. You can change your mind at any time in Settings → Advanced →
Anonymous Reports, which also shows exactly what would be sent.

A report holds only: the app version, platform, Android version, device make
and model, the date (no time), the kind of crash, the error class name, and
up to 30 lines saying where in the code it happened.

It never holds: playlists, logins, links, host names, IP addresses, channel
or title names, search text, settings, or anything from the database. There is
no install ID, so reports cannot be tied to each other or to you. A scrubber
removes anything that looks like a link, IP address or e-mail before a report
is saved. Reports are kept for 90 days and then deleted.

The code is small and open: `lib/telemetry/` and `tools/stats-worker/`. The
design is in [docs/design/anonymous-stats.md](docs/design/anonymous-stats.md).

## What OpenIPTV never does

- Never sells, shares or analyses your data, because it doesn't collect any.
- Never provides or links to streams or playlists.
- Never sends your playlists, logins or viewing history anywhere other than
  the provider you set up yourself.

## Desktop and web builds

These are in development and not released. Before they are, this page will be
updated to say whether anything differs there. Until then, nothing in them is
meant to send more than described above.

## Contact

Questions or concerns: open an issue at
https://github.com/Hunter-Clipper/OpenIPTV/issues.

*Last updated 2026-11-05.*
