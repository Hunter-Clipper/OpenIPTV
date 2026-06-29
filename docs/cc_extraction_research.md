# CC/Subtitle Extraction from Live MPEG-TS Streams — Research Findings
_Generated from deep-search workflow (74 agents), June 2026_

---

## The Core Question

**Can CEA-608/708 closed captions be extracted from a live IPTV MPEG-TS stream, and if so, how do other apps do it?**

---

## What the Research Confirmed

### 1. CC IS embedded in MPEG-TS — the data is there

CEA-608/708 captions are carried in two ways inside MPEG-TS:
- **H.264 streams**: Inside SEI (Supplemental Enhancement Information) NAL units, specifically user_data_registered SEI messages
- **H.262/MPEG-2 streams**: Inside video "user_data" structures (GOP user data)

This is not a separate elementary stream you can demux by PID. The CC bytes ride inside the video ES.

### 2. Extraction does NOT require video decoding

**This is the critical finding.** Multiple independent sources confirm that extracting CEA-608 only requires **bitstream parsing** — reading NAL unit headers and SEI payloads — not entropy decoding the pixel data. Tools that prove this:
- **CCExtractor** reads raw MPEG-TS and pulls CC by parsing NAL/SEI without decoding a single frame
- **ExoPlayer's TsExtractor** does it at the demux layer (before any video renderer touches the frame)
- **FFmpeg bitstream filters** operate on the encoded bitstream, no decode step

The claim that extraction is "infeasible without parsing the video stream" is true (you do have to parse the bitstream), but "parsing" ≠ "decoding". Parsing SEI headers is cheap; decoding frames is not.

---

## How Each Major App Handles It

### ExoPlayer / Media3 (Android-native)

**Mechanism:** Extracts CC at the extractor (demux) layer via `SeiReader` (H.264) and `UserDataReader` (H.262/MPEG-2). The extractor reads SEI NAL units on the fly and synthesizes a discrete text track with MIME type `application/cea-608`.

**Track exposure:** Appears as `Renderer:2 [ Group:0 [ Track:0, mimeType=application/cea-608, supported=YES ] ]` in the TrackSelector output — a synthetic track, not a container-level PID.

**Live MPEG-TS caveats:**
- If the MPEG-TS PMT has no caption_service_descriptor, ExoPlayer won't auto-detect CC. You must call `DefaultExtractorsFactory.setTsSubtitleFormats()` to hint the formats.
- For plain MPEG-TS UDP multicast (no HLS wrapper), `roleFlags` will never be set — you need a custom track selector override.
- CEA-708: supported in DASH (FMP4+SCTE only) and HLS on paper, but live MPEG-TS-based HLS streams have documented inconsistencies.
- H.262 support was added in ExoPlayer 2.4 (mid-2017) via PR #3114/commit 3c4b0aa, so it's not an initial capability.

**Bottom line for IPTV live:** ExoPlayer CAN do it for H.264/MPEG-TS HLS streams. For raw MPEG-TS (direct UDP/TCP), it needs format hints and has known edge cases.

---

### FFmpeg (which libmpv uses)

**Mechanism:** FFmpeg attaches CC bytes to each decoded video frame as `AV_FRAME_DATA_A53_CC` side data (an `AVFrameSideData` entry). The `cc_dec` decoder (`AV_CODEC_ID_EIA_608`, found in `libavcodec/ccaption_dec.c`) then processes this side data into rendered subtitle cues.

**CEA-608:** Fully handled by `cc_dec`.

**CEA-708:** **Not implemented.** `ccaption_dec.c` explicitly returns `AVERROR_PATCHWELCOME` for cc_type 2 and 3 (CEA-708 packet types). The codec long name reads `"Closed Captions (EIA-608 / CEA-708)"` but that's misleading — it only renders CEA-608. CEA-708 data is silently skipped. No merged patch adds CEA-708 decoding as of June 2026.

**mpv detection issue:** mpv issue #3968 was closed WONTFIX (~2016) because detecting CC presence in the FFmpeg demuxer required `AVStream.codec` (deprecated). However, later mpv issues (#6376, #8889) indicate EIA-608 support was subsequently added through other means. The state of the bundled libmpv in `media_kit_libs_video` is unclear without checking the build config.

---

### VLC

**Mechanism:** VLC uses its own MPEG-TS demuxer and parses CC from the video bitstream similarly to ExoPlayer. Has a separate CC display path.

**Reliability:** VLC's CC support on Android is documented as unreliable:
- Bug reports: phantom/empty CC track listings, CEA-708 misidentified as CEA-608, captions stopping mid-playback, CC menu not working on Android TV
- The 2017 observation that "VLC proactively offers all CC channels even if empty" was one user's speculation, not confirmed VLC behavior
- Not a model to emulate for reliable CC

---

## Why Our Current Setup (media_kit/libmpv) Shows No CC Tracks

Live logcat from v0.3.16 confirmed: subtitle track count stays at 2 (auto + no) throughout playback. No `application/x-subtitle` or CC-type tracks appear.

Most likely causes (in order of probability):
1. **Build config**: The bundled `libmpv` in `media_kit_libs_video` may not have `--enable-libass` or CEA-608 extraction configured. mpv requires `demux_lavf` to forward `AV_FRAME_DATA_A53_CC` side data and the `cc_dec` codec must be registered.
2. **Stream signaling**: Our test streams may not signal captions in the PMT. mpv/FFmpeg need to see the data or be told to look for it (`demuxer-lavf-o=scan_all_pmts=1` was already added — correct).
3. **FFmpeg deprecated API gap**: The old WONTFIX issue around `FF_CODEC_PROPERTY_CLOSED_CAPTIONS` means mpv might not know CC is present even when the bytes are there.

---

## Feasible Solutions for OpenIPTV

Listed from least to most invasive:

### Option A: ExoPlayer/Media3 swap (architectural change)
Replace `media_kit`/libmpv with ExoPlayer via the `just_audio` ecosystem or a custom platform channel. ExoPlayer has native MPEG-TS CC extraction built in. This is the most reliable path for Android live TV CC, but it's a large architectural rewrite — player API, state management, HW decode config, everything changes.

### Option B: Custom libmpv build (#26 in backlog)
Build libmpv for Android with:
- FFmpeg `cc_dec` enabled (usually is by default)
- Proper side data forwarding from `AV_FRAME_DATA_A53_CC` into mpv subtitle tracks
- Possibly patches from mpv issues #6376/#8889

Package the resulting `.so` as a replacement for `media_kit_libs_video`'s prebuilt. `media_kit` supports custom native libraries via `media_kit_libs_video_android`. Significant build effort but keeps the existing Flutter/Dart stack intact.

### Option C: App-side MPEG-TS CC parsing (extract ourselves)
Open a parallel byte-stream connection to the same MPEG-TS URL in a Dart isolate. Parse the MPEG-TS packet framing, identify the video PID, parse H.264 NAL units, extract SEI user_data_registered payloads, decode CEA-608 byte pairs, and render them as an overlay widget. This is what CCExtractor does. Hard to implement correctly (B-frame reordering, timing), but completely independent of libmpv.

### Option D: GStreamer (alternative to media_kit)
GStreamer for Android has a `closedcaption` plugin with `cea608parse`/`cea608overlay` elements that extract and render CEA-608 inline. There is a Flutter GStreamer plugin in development. Not a mature Flutter option today, but worth watching.

---

## Recommendation

**Short term:** Keep #26 (custom libmpv) in the backlog as the lowest-disruption path. Before committing to a full custom build, first check if `media_kit_libs_video` exposes any build options or alternate `.so` variants — some mpv builds for Android already have cc_dec enabled.

**If custom libmpv proves unworkable:** Option A (ExoPlayer swap) is the right long-term answer for Android IPTV. ExoPlayer is purpose-built for this. Libmpv's CC story on Android has been fragile for years.

**CEA-708:** Don't count on it from FFmpeg. It's not implemented in `ccaption_dec.c` and no merged fix exists. ExoPlayer handles CEA-708 in HLS/FMP4 streams but not in raw MPEG-TS. For IPTV live streams, CEA-608 (2-channel analog-era) is what most broadcasters embed anyway.

---

## Sources Summary

- ExoPlayer GitHub issues #2565, #3816, #6451, #7833, #10175 — CEA-608 in MPEG-TS behavior
- ExoPlayer GitHub issue #4308 — H.262 CC support commit (3c4b0aa, July 2018)
- mpv GitHub issues #3968 (WONTFIX), #6376, #7608, #8889 — mpv EIA-608 status
- FFmpeg `libavcodec/ccaption_dec.c` — CEA-608 only; CEA-708 returns AVERROR_PATCHWELCOME
- Android developer docs (developer.android.com/media/media3/exoplayer/supported-formats) — ExoPlayer CC format matrix
- ANSI/SCTE 20 — CEA-608 transport (not CEA-708)
- CCExtractor project — reference implementation for bitstream-level CC extraction
