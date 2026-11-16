# Themes and screen effects (#178)

Status: **phase 1 (plumbing) built** on this branch: per-profile theme setting, backup support, preview-card picker, two presets (Standard, True black). Phases 2-4 not started. Decisions below are the owner's answers to the Q&A.

## The ask

From the issue: fun themes, starting with a **vintage "OG cable box" look**
(the reference shots are 2000s cable guides: blue gradient panels, a cream
channel column, colour-coded programme cells, chunky type), plus an option
for a **CRT scan-line look over the whole screen**. More themes can follow.

## Where we are today

- One dark theme, `AppTheme.dark(accent)` (`lib/shared/theme/app_theme.dart`),
  with a per-profile accent colour (`Profile.accentColor`, saved in backups)
  and the Google Sans font. `themeMode` is fixed to dark.
- The guide's look lives in `tv_guide_screen.dart` (cells, channel column,
  header, now line), mostly through `ThemeData` colours.
- `Programme.category` exists, so a cell *can* be coloured by genre.

## Ideas

### 1. A theme is a bundle, not just a colour
A `ThemePreset` = colours + font + shapes (corner radius, gaps) + a few
extra tokens (guide cell colours, channel column colour, header style),
carried by a `ThemeExtension`. The accent colour stays a separate choice
that tints whichever preset is active (or is ignored by presets that fix
their own colours).

### 2. Screen effects are a separate layer
"CRT lines" is not a theme: it is an overlay drawn over the whole app
(`IgnorePointer`, cached scan-line tile, optional soft vignette). Keeping it
separate means any theme can have it, and it can be switched off without
touching the theme. Options to discuss: line strength, whether it covers
the video picture or only the interface, an optional slight glow.

### 3. A "Retro Cable" preset
Rough shape, from the reference images:
- deep-blue gradient panels, cream/pale channel column, flat rectangular
  cells with thin gaps and no rounded corners;
- cell colour by genre (sports green, movies purple, kids yellow, news
  blue...), falling back to the plain blue;
- a bold, slightly rounded font (needs a bundled font with a licence we can
  ship, as with Google Sans);
- focus = white/cream fill, like the reference.
Question: guide only, or the whole app (lists, settings, player)?

### 4. Where it is chosen
Settings → Appearance → Theme (and Screen effects). Per profile like the
accent (so a kids profile can have its own), or one for the whole device.

## Things to watch

- **No other brands.** The reference images show a cable company's and a
  listings brand's logos. We take the *feel* (colours, layout, scan lines)
  and ship none of their names, logos or artwork. Preset name is generic
  ("Retro Cable").
- **Chromecast performance.** A full-screen overlay repaints every frame.
  Draw the lines once into a cached image and keep it in its own repaint
  boundary; measure with `tools/guide-stress`.
- **Readability.** Scan lines and saturated colours must keep text
  contrast; a strength slider and a Reduce effects switch are cheap
  insurance. Respect Reduce Motion for any flicker/animation.
- **Backups** should carry the choice (same as accent).
- **Phones too?** The overlay and presets would work, but the guide skin
  only exists on TV today.

## Possible phases

1. Theme plumbing: `ThemePreset` + `ThemeExtension`, per-profile choice,
   backup, a picker. Default preset unchanged.
2. CRT overlay (works with any theme).
3. Retro Cable preset, including the guide skin and genre colours.
4. More presets (ideas below).

## Other theme ideas to collect

Terminal green, amber monochrome, "late-night" OLED black, high-contrast,
neon, light mode (we have none today — also an accessibility win).

## Decisions so far (owner Q&A, 2026-11-16)

| Topic | Decision |
|---|---|
| Retro Cable scope | **Whole app** (guide, lists, settings, player controls), not only the guide. |
| Who chooses | **Per profile**, like the accent colour; saved in backups. |
| CRT over video | **Everything, including the video picture.** On TVs the video sits on a layer *behind* Flutter (`videoLayerActive`, #162) and Flutter draws on top of it, so semi-transparent lines should blend over the picture; **to verify on the Chromecast** before promising it. |
| CRT controls | **On/off plus strength** (Light / Medium / Strong). |
| First presets | Retro Cable, **terminal green, amber monochrome, true-black OLED, light theme**. |
| Font | **A free open-licence font** (SIL OFL or similar); I shortlist 2-3 with previews, owner picks. |
| Guide cell colours | **By genre** from `Programme.category`, unknown stays plain blue. |
| Picker | **Preview cards**: Settings → Appearance → Theme shows a small mock guide per theme and applies the choice instantly. |
| Kids profiles | **Admin decides**: an admin sets a kids profile's theme, the child can't change it. |
| Genre mapping | **Keyword buckets** (sports, movies, kids, news, other), matched on the programme category like the genre-icon logic (`genre_icons.dart`); unknown stays plain blue. |
| Accent colour | **Ignored on fixed-colour presets** (Retro Cable, terminal green, amber): the theme owns its colours and the accent swatches are greyed out with a note. Normal themes (Standard, OLED, Light) keep the accent. |
| Retro Cable palette | **Classic blue**: deep-blue gradient panels, cream channel column, white focus, genre colours on the cells. |
| Retro Cable cells | **Flat blocks with thin gaps** (square corners, bold title). |
| Retro Cable layout | **Skin plus retro touches**: same layout and navigation, plus small touches such as a "Today ◄ 3:30p ►" header strip and channel numbers. |
| Fonts | Retro Cable: **Nunito Bold**. Terminal green and Amber: **JetBrains Mono**. All open licence (SIL OFL); bundle only the weights used and add their licence texts to the notices. |
| Light theme | **Clean cool white**: near-white backgrounds, dark text, the user's accent as highlights. |
| Terminal green / Amber | **Pure black, one colour**: black background, text and highlights all in the one phosphor colour. |
| True-black OLED | **Pure black backgrounds, otherwise like Standard; the accent still applies.** |
| CRT effect | One **Screen effects** page under the theme settings: **scan lines** (Light / Medium / Strong), plus an on/off toggle for **soft glow/vignette**. Everything off by default. (Flicker was built, then **removed at the owner's request** — they didn't like it.) |
| Mono cells | Outlined cells on black, **inverse (solid fill, black text) on focus**, a brighter outline for what's airing now. |
| Build order | 1 plumbing + picker, 2 CRT overlay, 3 Retro Cable, 4 the other presets. |

Notes from the decisions:
- A **light theme** touches every hard-coded dark colour in the app
  (`AppTheme` constants and widgets that use them directly), so it is the
  largest of the presets and should be audited before it is promised.
- Whole-app Retro Cable means the preset must cover every component theme
  (dialogs, sheets, chips, snackbars, nav rail, player controls), not just
  colours; component themes must name `fontFamily` or they fall back to
  Roboto (known gotcha).

Consequences to handle:
- Monochrome presets have no genre colours: cells need another way to tell
  programmes apart (outline weight, inverse on focus, a marker for what's
  airing) — to design.
- **Flicker must obey Reduce Motion / system animation settings** and stay
  very subtle; it is the one effect that can bother some viewers, so it
  stays off by default and has its own toggle.
- Glow/vignette costs raster time on the Chromecast: measure before
  shipping, and keep it a separate toggle.

## Still open
- Name and visual identity of each preset (palette, accent behaviour).
- Confirm each font's licence file and weight subset before bundling (APK size).

## Phase 1 as built (0.14.125, test builds)

- `ThemePreset` (`lib/shared/theme/theme_preset.dart`): `standard`, `trueBlack`; `fixedColours` is false for both (the retro presets will set it).
- Stored on the profile (`Profile.themeId`, DB schema 17, backup profile map) and cached in prefs (`themeId`, in backups) like the accent; the runtime value is `themePresetProvider`, applied through `AppTheme.forPreset` in `app.dart`.
- Settings → Appearance → Theme opens a picker with a mini guide preview per preset; hidden on kids profiles (an admin-sets-it screen is still to do).
- Verified on the Chromecast: picker opens with the remote, True black applies at once and survives an app restart, accent kept.

Still to do for kids profiles: let an admin set a child's theme from the profile screen.

## Phase 2 as built (0.14.126, test builds)

- `ScreenEffects` (`lib/shared/theme/screen_effects.dart`): scan lines (Light / Medium / Strong) and soft glow and vignette; each its own switch, all off by default. Stored device-wide in prefs (`crtLines`, `crtStrength`, `crtGlow`), in backups.
- Drawn by `ScreenEffectsOverlay` in the app builder, above every page, dialog and sheet, ignoring touches and the remote. The lines are ONE repeating-gradient rectangle (1 dark physical pixel in 3), so the cost is near zero.
- "Soft glow" is a vignette with a faint warm centre, **not a real bloom** (a blur over the whole screen is too costly for the Chromecast).
- Settings → Appearance → Screen effects (dialog with the switches; changes show at once).
- Checked on the Chromecast: dialog works with the remote, lines and darker corners are visible in screenshots.
- **Not verified: lines over live video.** The video layer is not captured by screenshots (the preview pane shows black), so whether the translucent lines blend over the picture on TVs with the video layer has to be checked by eye.

## Phase 3 as built (0.14.128, test builds)

- `ThemePreset.retroCable` (`fixedColours: true`, accent ignored and the accent row says "Set by the theme"). `RetroCable` (`lib/shared/theme/retro_cable_theme.dart`) re-colours and re-types the whole app: deep-blue page, blue panels, cream channel column, yellow titles/selection, Nunito (Regular + Bold bundled, SIL OFL), square-ish corners, flat components.
- `GuideStyle` (`guide_style.dart`) is a `ThemeExtension` only Retro Cable provides; the TV guide uses it when present: genre-coloured flat cells (sports green, movies purple, kids yellow, news blue, else blue; `genre_colors.dart` keyword buckets, programme category first then the channel's categories), white focus block with dark text, cream channel column with channel numbers, blue gradient header strip with ticks and a "Today ◂" label, gradient top panel.
- Owner feedback after the first look: channel logo + name centred in the cream column, logos transparent (no tile), and the preview pane's "Press OK to preview" text and channel logo removed **for every look** (only a "channel unavailable / denied" note remains).
- Known trade-off: a white logo nearly vanishes on the cream column (transparent logos were requested). Options if it bothers: a subtle dark backing only for light logos, or a darker channel column.
- Not done yet: the first-run wizard stays on the standard dark look; light/terminal/amber presets (phase 4); admin setting a child's theme.

### Retro Cable follow-up (0.14.129)

- The logo and name now form one block centred in the cream column after the channel number (names centred).
- **3D drop shadow under each bare logo** (`GuideStyle.logoShadow`): the logo drawn again in a navy tint, offset down-right, twice (far one lighter), then the logo on top. A first version used a blurred shadow (`ImageFiltered`) and **halved the guide's frame rate** on the Chromecast (raster ~17 ms vs ~8 ms; 50-70 % slow frames), because blur filter layers are not cached. Plain tinted draws (`CachedNetworkImage(color:, colorBlendMode: srcIn)`) have no filter layer. The channel column also sits in its own `RepaintBoundary` so it is not redrawn while programmes slide.
- Measured with `tools/guide-stress`: Retro Cable is still a little heavier than Standard (roughly 10-20 % slow frames vs 5-10 %). Candidates if it matters: draw one shadow copy instead of two, or cache the composed logo as a bitmap.

## Phase 4 as built (0.14.131, test builds)

- **Shared builder:** `buildFlatTheme(FlatPalette)` (`flat_theme.dart`) now makes Retro Cable, Terminal green, Amber and Light from a palette (colours, font, corner size, brightness, optional `GuideStyle`).
- **Terminal green / Amber** (`terminal_looks.dart`): pure black, one phosphor colour, JetBrains Mono (Regular + Bold, SIL OFL). Guide cells are outlines (brighter and thicker for what's on now); the focused cell fills solid with black text (`GuideStyle.outlined`). Channel logos keep their grey tile (`bareLogos: false`) so dark logos stay visible on black. Accent ignored.
- **Light** (`light_look.dart`): near-white, cool, the normal font and corner size, the accent applies. No guide style (the standard guide, in light colours).
- Picker lists all six looks; the focus/selection colour in the picker follows the theme.
- **Retro Cable polish from owner feedback:** logos get a soft, feathered drop shadow composed once into a cached bitmap (`ShadowedLogo`: logo + blurred tinted copy drawn into a `ui.Image`, kept by url/size), so no blur filter runs per frame; logo and name left-aligned and vertically centred (`Positioned.fill` row); channel logos bigger in the guide (58 px, column 224 px); bare logos use less padding.
- **Settings:** TV Guide Layout moved from Watching to the end of Appearance.
- Not covered yet: the first-run wizard (still standard dark); a screen-by-screen audit of Light for hard-coded dark colours (Movies/Series/detail/player screens not reviewed); admin setting a child's theme; frame-time check of the terminal looks.
