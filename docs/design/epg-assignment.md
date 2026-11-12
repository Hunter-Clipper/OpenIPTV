# Extra guides, smart and manual guide assignment (#40)

Status: in development (branch `feature/40-epg-assignment`).

## The problem

A playlist's own guide only covers channels the provider gave a guide id
(`tvg-id` / `epg_channel_id`). On the owner's main playlist that is 2,278 of
17,765 channels; the rest say "No guide information" and nothing the app does
with the provider's guide can change that. Users also ask to pick a guide
for one channel by hand (hold OK / long-press → Change Guide).

## What we are building

1. **Extra guides** — XMLTV URLs the user adds once (Settings → Live TV →
   Extra Guides), independent of any playlist. Public examples used for
   testing: `https://iptv-epg.org/files/epg-us.xml` (522 MB raw, 12.8k
   channels, 1.1 M programmes) and `epg-gb.xml` (71 MB, 932 channels).
2. **Smart assignment** — for channels that have no working guide, match the
   channel's name to the extra guides' channel names and link them.
3. **Manual assignment** — hold OK / long-press a channel → Change Guide:
   search the guide channels (all playlists' guides and extra guides), pick
   one, or "No guide" / "Use automatic".

## Rules (owner decisions, 2026-11-11)

- **The provider's guide always has priority.** A channel whose own link
  (`tvg-id` / `epg_channel_id`) already finds programmes is never touched.
- Smart links only fill gaps: channels with no guide link, or a link the
  provider's feed does not contain.
- **Matching pool, in priority order:** (1) the channel list of the channel's
  own playlist guide — providers often have the programmes but forgot the
  link; (2) the extra guides, in the order the user lists them. A tie between
  the same station in two guides goes to the one listed first.
- A manual link always wins over everything, including the provider's guide.
- Auto links are only made above a confidence threshold; a wrong guide is worse
  than none. Ambiguous matches (two equally good candidates in one guide) are
  skipped.
- Links are per channel and survive playlist refreshes (keyed by the channel's
  stable id, `<sourceId>_ch_<streamId>`).
- Nothing is sent anywhere except the guide URLs the user typed.
- Backup includes extra guides and manual links; auto links are recomputed.
- **No guide URLs are offered or built into the app** (no-content policy; owner
  decision 2026-11-11). The Extra Guides screen carries only a knowing hint
  that guide files are published by community sites and a web search for
  "XMLTV EPG" is a good place to start, and says it accepts XML, XML.GZ and
  zipped files as long as they unpack to XML.
- Candidates Candidates used for testing: iptv-epg.org (`epg-us.xml`,
  `epg-gb.xml`) and epgshare01.online (small per-country files, e.g.
  `epg_ripper_UK1.xml.gz` 2.9 MB, `epg_ripper_US2.xml.gz` 6.6 MB).

## Local stations (US)

epgshare01's locals file is keyed by call sign (4,471 stations). `local_stations.dart`
resolves in two tiers, precision first: (1) a call sign in the name that the
guide has; (2) network + city through a small market table (only stations
verified against the guide's own programming on 2026-11-11; Atlanta's CBS/CW
were dropped when the guide showed the affiliation had moved). Never linked:
sub-channels (`2.2`, "Telemundo KNSD"), ordinary channels containing a call
sign ("WOW Kidz", "King TV"), cable cousins (FOX News), or a name that looks
local but cannot be resolved (it must not fall back to the national guide).
Checked on 620 generated provider-style names for every table entry: 620
right, 0 wrong; and on 11,461 real playlist names: no false local links left.

## What the test feeds taught us

- epgshare01 channels have **no display name**, only an id like
  `BBC.One.HD.uk`; the matcher reads names out of ids and takes the region
  from the id suffix (`uk`, `us2`).
- iptv-epg.org's US file is 522 MB raw (12.8 k channels, 1.1 M programmes):
  only practical because we read its channel list and keep programmes just
  for linked channels. epgshare01's per-country files are far lighter for a TV.
- The same station appears in several guides with different ids
  (`BBCTwo.uk`, `BBC.Two.HD.uk`): priority order decides.
- Regional variants (`FX.HD` vs `FX.HD.(Pacific)`) prefer the plain one;
  `AMC` and `AMC+` are different channels; `BBC 1` is never `BBC 2`.

## Size and speed (the 522 MB file)

- Matching only needs the `<channel>` list, which sits at the top of the file:
  read until the first `<programme>` and stop. Cheap even for the US file.
- Programmes are then streamed and **only kept for guide ids that some channel
  is linked to** — the other 1.1 M programmes are dropped while parsing, so a
  TV never holds them. gzip is requested (the server supports it).
- Extra-guide refresh rides the existing guide refresh (Refresh TV Guides,
  background refresh) and honours "days of guide to keep".

## Data model (schema 15)

- `epg_sources(id, name, url, enabled, last_updated, last_error, channel_count)`
- `guide_channels(epg_source_id, xmltv_id, name, icon)` — the channel list of
  every extra guide, used for matching and the manual picker.
- `channel_guide_links(channel_id PK, epg_source_id NULL, xmltv_id NULL,
  kind 'manual'|'auto', score)` — `kind='manual'` with a null xmltv_id means
  "no guide for this channel".

## Matching

`lib/core/epg/guide_matcher.dart`, pure and unit-tested. Normalise both names
(lower case, drop country/region markers like `UK -`, `(USA)`, `|US|`, quality
words HD/FHD/4K/SD/RAW, symbols, `+1`-style time shifts kept as a token),
then score by token overlap with region/country hints from both names.
Evaluated against the real iptv-epg files in tests and by a throwaway harness.

## Phases

1. Matcher + tests (done); channel-list parser (next).
2. Schema 15, extra-guide store, filtered programme import.
3. Smart assignment run + Settings → Extra Guides screen.
4. Change Guide on hold OK / long-press (TV and phone).
5. Backup, changelog, device testing on the Chromecast and phone.
