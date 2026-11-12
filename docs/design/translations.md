# Translations and a language picker (#172)

Status: proposal, owner decisions recorded below (draft PR). No code yet.

## The decision in one line

One **app-wide** language, chosen once, stored in the app preferences and
carried by backup/restore. It is not a per-profile setting.

## Scope and rules

- **Automatic by default.** The language starts as *Auto-detect from system*.
  The app uses the device language if we ship it, otherwise English.
- **Setup wizard.** A new first step, shown only on a fresh install (never in
  "Add Playlist" mode): *Auto-detect from system* (preselected, shows what it
  resolved to, e.g. "Auto — Español") or a drop-down of every shipped
  language. The wizard re-renders in the chosen language straight away.
- **Settings → Appearance → Language.** Same list. Changing it applies at once
  with no restart. Admin-only like the other app-wide Appearance settings.
- **Backup/restore.** New `language` entry in `_backupPrefEntries`
  (`'auto'` or a language tag such as `'es'`, `'pt-BR'`). Restoring on a
  device whose language we don't ship falls back to English; the saved value
  is kept so it works again once that language is added. Old backups have no
  key and are skipped by the existing null guard.
- **Not translated:** provider/EPG content (channel, movie and programme
  names), the user's own profile and playlist names, log lines (`[OTV-…]`),
  crash reports, and the "no-content" wording rules still apply to every
  language.

## Approach (top down)

1. **Plumbing first, no visible change.** Add `flutter_localizations` + `intl`,
   `l10n.yaml`, `lib/l10n/app_en.arb` as the template. Wire
   `localizationsDelegates`, `supportedLocales` and `locale` on all three
   `MaterialApp`s in `app.dart` (splash, profile picker, router) so the picker
   and splash also follow the language.
2. **`languageProvider`** (app preferences, key `language`) →
   `localeProvider` that resolves *auto* against
   `PlatformDispatcher.locale(s)` using the shipped list (first match on
   language, then language+country, else English).
3. **Convert strings feature by feature**, each its own commit and test run,
   starting with the screens a new user meets: wizard → Live TV / Movies /
   Series shells → player → Settings → the rest. About 550 `Text(` sites in 61
   files today; the long tail is info-tooltips and error messages
   (`friendly_error.dart`, `friendlySourceErrorMessage`).
4. **Language picker** (wizard step + Settings tile + backup entry) lands
   right after step 2, before the bulk conversion, so it can be tested with a
   pseudo-locale while strings move over.
5. **First translations**, then contribution flow (below).

## Details that need care

- **Plurals and placeholders** use ICU in the ARB files (`{count, plural, …}`);
  no string concatenation for sentences. `display_name.dart` currently drops
  English from names; it stays language-independent.
- **Dates, times and numbers** switch to `intl` formatters
  (`format.dart`: `formatClock`, `formatRuntime`, `formatYmd`) so they follow
  the locale. The TV guide's 12/24-hour handling must keep honouring the
  system clock setting.
- **Font.** Google Sans is bundled as a *subset* (Latin). Cyrillic, Greek,
  Arabic, Hebrew, CJK, Thai, etc. fall back to the system font; confirm each
  language we ship renders properly on the Chromecast and Mi TV before
  claiming it. Extending the subset costs APK size.
- **Right-to-left** (Arabic, Hebrew): not in the first batch. Flutter flips
  layouts for free, but the TV guide grid, player controls and rails need a
  deliberate pass; ship RTL only after that.
- **Text fit** (checklist item in #172): long languages (German, Finnish,
  Russian) run 30–40 % longer. Check the nav rail labels, TV guide cells,
  player buttons, settings rows and dialogs with the largest Text Size and a
  pseudo-locale of padded strings, on the phone and both TVs.
- **System UI the app doesn't draw** (Android notification channel names,
  media session, Android Auto browse tree labels, cast, PiP actions) is
  native. Strings go in `android/.../res/values-xx/strings.xml`, or are
  passed from Dart when the language changes. Listed separately and done after
  the Dart side.
- **Engine-language vs app-language.** Flutter's `locale:` override only
  affects Flutter widgets. Native code reading `Locale.getDefault()` still
  sees the device language; any native text must take its language from Dart.
- **First paint.** The language is read with the other prefs before `runApp`
  where possible so the splash and wizard don't flash English.

## Contributing translations

- Source of truth: `lib/l10n/app_<tag>.arb`, English is the template. Anyone
  can open a PR that adds or edits one file; no code knowledge needed.
- CI check: `flutter gen-l10n` must succeed, and a test fails if a translation
  is missing a placeholder the English string has.
- Missing keys fall back to English per string. A language appears in the
  picker once it is at least 90 % complete (owner decision).
- Short `docs/TRANSLATING.md` explaining the above in plain words.
- **Decision: plain ARB pull requests** (a hosted site like Weblate is more
  upkeep than a solo project needs; the ARB format lets us move later).

## First languages (owner: ship the most common ones)

- **Batch 1 (Latin scripts, covered by the bundled font):** Spanish,
  Portuguese (Brazil), French, German, Italian, Dutch, Polish, Turkish.
- **Batch 2 (needs the font check):** Russian, Ukrainian, Greek (Cyrillic and
  Greek glyphs are missing from the Google Sans subset).
- **Batch 3 (needs the font check and the RTL pass):** Arabic, plus Hindi and
  Chinese/Japanese/Korean if there is demand (large fonts, APK size).

Translations are machine-drafted and flagged as such in the PR until a native
speaker reviews them. A language ships in the picker once it is 90 % complete
(owner decision).

## Testing plan

- Unit: locale resolution (exact, language-only, unsupported → English), ARB
  placeholder parity, backup round-trip of `language` including an old backup
  without it.
- Widget: wizard step (auto vs explicit), Settings tile switches language
  live.
- Device: phone + Chromecast + Mi TV in two languages, D-pad focus through the
  new wizard step and the language list (TV: drop-down must be a TV-friendly
  sheet, not a tiny popup).
- Pseudo-locale run for overflow before each language is added.

## Phasing / PR plan

1. Plumbing + language preference + Settings tile + wizard step + backup
   (English only, plus a pseudo-locale in debug builds).
2. String conversion, in reviewable chunks (wizard/shell, player, settings,
   rest, errors and tooltips).
3. First translations + `TRANSLATING.md` + CI check.
4. Native strings (notifications, Android Auto, cast).
5. RTL and extra scripts.

Nothing is released without the owner's go-ahead.

## Decisions (owner, 2026-11-12)

- Ship the most common languages (batches above).
- 90 % completeness before a language is listed.
- ARB pull requests, no hosted site for now.
- **Auto follows the system**: the stored value stays `auto`, and the app
  re-resolves when the device language changes (Flutter
  `didChangeLocales`), live, without a restart.
