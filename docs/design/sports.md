# Sports fixtures tab — design (draft)

Status: **v1 built (2026-11-19), unreleased, tested on the Chromecast.**
Decisions below come from the owner's Q&A on 2026-11-19.

What exists: `lib/features/sports/` (matcher, ESPN source, catalog, models,
providers, Sports screen, match sheet, settings page, reminder worker), the
`/sports` shell tab (shown only when enabled and not a kids profile) and
`/settings/sports`. Tests in `test/features/sports/`.

Built differently from the first plan:
- **Free source = ESPN's public scoreboard** (no key, covers all three sport
  groups). ESPN's date-range queries are unreliable, so the tab fetches ONE
  local day per selected league (cached 1 min, refreshed every 45 s on
  Today). ESPN days are US-Eastern, so games near midnight can land on a
  neighbouring day for far time zones. It is an unofficial endpoint: keep it
  behind `SportsSource` so it can be swapped.
- **Event-channel dates:** the provider's time zone is unknown, so event
  channels match within ±14 h of kickoff; both team names are what identify
  the game.
- **Reminders** use the existing WorkManager dispatcher (a 15-minute check;
  followed-team games cached 6 h) rather than exact alarms (no `timezone`
  package). Timing is approximate; battery optimisation can delay it.
- Strings are plain English literals in the new screens, not yet in the ARB
  files (follow-up).
- **Not built yet:** the user's own API key option (needs a second
  `SportsSource`), backup/restore of Sports settings.

**Matching round 2 (2026-11-20):** the guide search reads title AND
description (`searchProgrammesWithText`, bounded by the kickoff time
window) because local stations name the teams only in the description of a
generic "NFL Football". One-team guide hits need sport words or the league
in the text; a clear "X vs Y" where Y is someone else's team is rejected.
Unmeasured on the TV: the description scan reads full rows in the window.

## Goal

A user who wants a game or a score finds it quickly: **Sports tab → tap a
game → sheet of best-matched channels from their own playlist → tap one to
play.** Three taps, in line with the project's guiding principle.

## Decisions

| Topic | Decision |
|---|---|
| Entry point | An extra tab (phone bar + TV rail), shown only when Sports is enabled |
| Master switch | Settings → Sports → "Show Sports". **Off by default** for new installs and updaters. While off: no tab, no network calls to any sports source |
| Sports in v1 | Football (soccer), American sports (NFL/NBA/MLB/NHL), motorsport / combat / tennis |
| Filtering | User picks leagues in Settings → Sports; the tab shows only those. Followed teams pin to the top |
| Data source | Free source by default. Optional "My API key" replaces it (key in secure storage, never uploaded, excluded from backups, Test button) |
| Scores | Schedule + live scores. Scores refresh only while the tab is open |
| Spoilers | Settings → Sports → "Hide scores": scores show as "–" until tapped |
| Kid profiles | Tab hidden for kid profiles. Admin and standard profiles see it when the switch is on |
| TV | Full support from v1 (rail destination, D-pad focus, remote-friendly sheet) |
| Reminders | In v1, for **followed teams only** |
| Matcher strictness | Balanced: one team plus a time window counts, labelled "Possible"; both teams / event name is "Best" |
| No match | Say so plainly and offer a search of the playlist by team or league name |

## Game states

- **Live:** ranked channels, tap to play.
- **Finished:** catch-up where the channel supports it, using the existing
  `openChannelWithStartChoice` / catch-up launcher.
- **Upcoming:** show likely channels ahead of time, labelled "Likely", and
  refresh the list as kickoff approaches and guides fill in.

## Matching (the risky part)

Only the user's own active playlist is searched. Nothing is listed, linked
or explained about where to get streams (no-content policy).

**Update (same day, after the first TV test):** the first matcher missed the
real package channels, so it was rewritten around what the provider
actually uses. Channels are now matched by their OWN NAME wherever both
teams appear (any order, any separator, nicknames allowed): e.g.
`NFL : 01 - TNF 8:15pm Colts at Texans`, `NHL: 02 - 7pm Flyers @ Senators`,
and stream entries like `Indianapolis Colts vs. Houston Texans (date)`. A
date in the name (ISO, `Nov 19`, `11/19`) must be within a day of kickoff or
the channel is a different day's game; a time alone (`8:15pm`) carries no
date. A lone nickname is never enough in a channel name ("Blues Clues");
a team feed named with the full name or nickname + city counts as Possible.
Guide titles about the game (pregame, highlights, countdown...) are demoted
to Possible. Candidate channels are fetched by team name
(`getChannelsNamedLike`), not by a name pattern. The earlier text below
describes the first version.

Signals (measured on the Chromecast with a real 16k-channel playlist,
2026-11-19; the guide was empty until a refresh, so neither signal can be
assumed present):

1. **Guide (EPG) hit:** a programme whose title contains both teams, either
   airing at kickoff or starting within 30 minutes of it. Real titles look
   like `A vs B - League ...`, `A v B` and `Away @ Home`. An `@` followed
   by a clock time ("News @ 6pm") is **not** a fixture. The same programme
   repeats on many channels and in several quality variants of one channel.
2. **Event channel:** the channel name carries the game and its date, e.g.
   `Team A vs Team B @ Nov 19 6:50 PM :League 01`, under a PPV/EVENTS group
   with ~50 slots per league. Most slots are empty placeholders and filled
   ones go stale after the game, so the date in the name must be parsed and
   checked. The time zone of that date is unknown and has to be calibrated
   against real fixtures (`providerUtcOffset`).
3. **One team + time window:** labelled "Possible".
4. **Tie-breakers:** quality tags (4K / 1080 / 720), favourites, catch-up.

Quality variants of one channel (`[720p]`, `[H265] [1080p]`, `UK:` prefix,
decorative symbols) fold into the best one, with an "other versions" count.

First implementation: `lib/features/sports/fixture_matcher.dart`, tests in
`test/features/sports/fixture_matcher_test.dart` (made-up names only).

Broadcaster hints (league → generic channel names) are not shown as matches.

Needs: team-alias table ("Man Utd" / "Manchester United"), diacritics and
punctuation folding, "v" / "vs" / "-" separators, time-zone handling.
Lessons from the #40 guide matcher apply: audit real matches against real
data with a temporary dump, prefer exact matches, benchmark on desktop and
multiply by ~30 for the Chromecast, run in the DB isolate, never use
`isIn()` with catalog-sized lists, give big-table queries a narrow index.

## Data layer

- A `SportsProvider` interface with two implementations: free source and
  user-key source. League ids and team names are normalised into one
  app-owned model so the rest of the app doesn't care which one is active.
- The free source must cover all three sport groups. **Not yet researched.**
  Candidates: TheSportsDB free tier, ESPN endpoints, football-data.org,
  API-Football. Compare coverage, rate limits, licence terms and
  commercial-use clauses before picking.
- Cache responses on disk with short lifetimes (fixtures hours, live
  scores seconds while the tab is open). Failures keep the cached list and
  show a plain-English note.
- Privacy: fetching sends the device IP to the data provider, so the
  switch is opt-in and the first enable shows a one-time plain note.

## Settings → Sports

- Show Sports (master switch)
- Leagues (grouped by sport)
- Followed teams
- Hide scores
- Kickoff reminders (followed teams; notification permission requested on
  first enable)
- Data source: Free / My API key (+ Test)

## UI sketch

- Fixtures list grouped by day. Live games pinned to the top with a live
  badge. League chips filter the list. Row = teams, score or kickoff time.
- Match sheet (reuse `showPlayerSheet` language): game header, ranked
  channels with a one-line reason ("On the guide now"), "Best" / "Possible"
  / "Likely" labels, and a "Search channels" button when empty.
- TV: rail destination, focusable rows (`TvFocusable`), sheet autofocuses
  the first channel.

## Open questions

1. Which free data source covers all three sport groups well enough?
2. Phone bar already has 5 destinations; a 6th makes it crowded. Check
   label length and touch targets on small phones.
3. Reminders for followed teams: how many days ahead to schedule, and how to
   handle postponements (cancel on next fetch).
4. Time zones: show kickoff in device local time; check around DST.
5. Match-quality target: measure on the owner's real provider before UI
   polish. Prototype the matcher first.
6. Does a user key need per-provider settings (endpoint, plan limits)?

## Suggested build order

1. Matcher prototype against real EPG and channel names (no UI).
2. Data source research and `SportsProvider` with the free source.
3. Settings → Sports + master switch + tab shell.
4. Fixtures list and live scores.
5. Match sheet, catch-up and no-match search.
6. Followed teams and reminders.
7. User API key option.
8. TV focus pass and Chromecast measurements.
