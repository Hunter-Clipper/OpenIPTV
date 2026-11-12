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

## Rules (decisions to confirm with the owner)

- A channel that already has programmes from its own playlist's guide is never
  auto-assigned. A manual link always wins over everything.
- Auto links are only made above a confidence threshold; a wrong guide is worse
  than none. Ambiguous matches (two equally good candidates) are skipped.
- Links are per channel and survive playlist refreshes (keyed by the channel's
  stable id, `<sourceId>_ch_<streamId>`).
- Nothing is sent anywhere except the guide URLs the user typed.
- Backup includes extra guides and manual links; auto links are recomputed.

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

1. Matcher + channel-list parser + tests (this PR's first commits).
2. Schema 15, extra-guide store, filtered programme import.
3. Smart assignment run + Settings → Extra Guides screen.
4. Change Guide on hold OK / long-press (TV and phone).
5. Backup, changelog, device testing on the Chromecast and phone.
