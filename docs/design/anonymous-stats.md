# Optional anonymous crash and error reports (#150)

Status: design for owner approval. No code yet.

Goal: learn about crashes and playback failures nobody reports, without
collecting anything about a person, a provider or what they watch. Off by
default for everyone. Every line of this feature lives in one folder
(`lib/telemetry/`, plus one small Kotlin file) so it can be audited in
minutes.

## What is sent (the complete list)

One small JSON report per event:

| Field | Example | Why |
|---|---|---|
| `v` | `1` | payload version |
| `app` | `0.14.51+17` | which build crashed |
| `platform` | `android` or `android-tv` | layout-specific bugs |
| `os` | `34` | Android API level |
| `device` | `Google Chromecast` (maker + model) | hardware-specific bugs |
| `day` | `2026-11-03` | the date only, no time, no time zone |
| `kind` | `crash`, `native-crash`, `playback-error` | what happened |
| `error` | `StateError` | exception class name only |
| `stack` | up to 30 lines of function name + file:line | where it happened |
| `code` | `ERROR_CODE_IO_BAD_HTTP_STATUS`, `404` | playback errors only: player error name and HTTP status |

**Never sent:** exception messages (they can contain links or names), URLs,
host names, IP addresses, logins, playlist or profile names, channel, movie or
series titles, search text, settings, device or advertising IDs, account
details, anything from the database. There is **no install ID**: reports
cannot be tied to each other or to a person. (Trade-off: you can count
reports, not unique users.)

A scrubber runs on every report before it is saved and drops anything that
looks like a URL, IP address or e-mail, and any stack line that is not code
(`package:`, `dart:`, `androidx.`, `com.openiptv.`). It has unit tests.

## Consent

Off until the user says yes. `stats_choice` preference: unset / on / off.

- **Updating users:** one dialog the first time the new version opens, only if
  the choice is unset. "Not now" counts as an answer (off) and it never asks
  again; the choice stays in Settings.
- **New users:** one step in the setup wizard, same wording, same two buttons.
- **Settings → Advanced → Anonymous Reports:** the toggle, plus **See exactly
  what is sent** (the field table above and the last reports queued on this
  device, shown as the raw JSON) and a **Delete queued reports** button.

Draft wording (plain English, no brand names):

> **Help improve OpenIPTV?**
> OpenIPTV can send an anonymous report when the app crashes or a stream
> fails to start. A report holds the app version, your device model and where
> in the code the problem happened. It never holds your playlists, logins,
> links, channel names or what you watch, and it can't be tied to you.
> This is off unless you turn it on. You can change your mind any time in
> Settings, and you can see exactly what is sent. The code that does this is
> small and open on GitHub if you want to check it.
> [Turn On] [No Thanks]

## How it works

- `lib/telemetry/` : `report.dart` (the payload type, the only place fields
  are defined), `scrubber.dart`, `queue.dart` (keeps up to 20 reports in a
  file; oldest dropped), `sender.dart` (HTTPS POST), `consent.dart`.
- Catches Dart errors (`FlutterError.onError`, `PlatformDispatcher.onError`)
  and native crashes (a Kotlin `UncaughtExceptionHandler` writes the report to
  a file; Dart reads and queues it on the next launch). Playback errors come
  from the player's existing error event.
- Nothing is queued or sent while consent is off. Turning it off clears the
  queue.
- Sending: next launch and then at most once a day, on any network, in the
  background; failures just retry later; one short HTTP request, no cookies.
- Never delays startup, never blocks playback, never throws: every call is
  wrapped so telemetry cannot cause a crash.

## Receiver

A small Cloudflare Worker (`tools/stats-worker/`, in this repo) you deploy
with your own Cloudflare account:

1. Accepts only `POST`, only JSON of the exact schema above, size-capped;
   anything else is rejected.
2. Writes the report to an R2 bucket under `reports/YYYY-MM-DD/<random>.json`.
3. The bucket has a 90-day lifecycle rule that deletes old reports.
4. Rate limiting per IP in the Worker (the IP is used for the limit only, held
   in memory, never written to R2).
5. Only you can read the bucket (no public access).

Honest limit: Cloudflare itself sees the connection (including the IP) like
any web host, and its own platform logs are outside this app's control. The
reports we store contain no IP.

## Build order

1. `report.dart` + scrubber + unit tests, Worker code and its tests.
2. Queue and sender, Dart and native crash capture, playback error capture.
3. Consent: Settings toggle and "See what is sent", update dialog, wizard step.
4. Changelog and a privacy section in the README (what, why, how to audit).

## Questions for the owner

1. Is the field list above right? Anything to drop or add?
2. Include playback errors (error name + HTTP status only), or crashes only?
3. No install ID (counts only, no unique users): OK?
4. Is the Worker's address a `workers.dev` URL or one of your domains? I will
   keep it in a single constant.
5. Wording of the prompt: any changes?
