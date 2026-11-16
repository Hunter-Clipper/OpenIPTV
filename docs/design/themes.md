# Themes and screen effects (#178)

Status: **brainstorm** — nothing built yet. This PR holds the discussion.

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
| Build order | 1 plumbing + picker, 2 CRT overlay, 3 Retro Cable, 4 the other presets. |

Notes from the decisions:
- A **light theme** touches every hard-coded dark colour in the app
  (`AppTheme` constants and widgets that use them directly), so it is the
  largest of the presets and should be audited before it is promised.
- Whole-app Retro Cable means the preset must cover every component theme
  (dialogs, sheets, chips, snackbars, nav rail, player controls), not just
  colours; component themes must name `fontFamily` or they fall back to
  Roboto (known gotcha).

## Still open
- Name and visual identity of each preset (palette, accent behaviour).
- The font shortlist (2-3 open-licence candidates with previews).
