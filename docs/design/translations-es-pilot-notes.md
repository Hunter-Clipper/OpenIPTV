# Spanish translation pilot: notes for review

Files: `lib/l10n/app_en.arb` (template) and `lib/l10n/app_es.arb`, 144 keys
each. No Dart was changed; the keys are not wired into the app yet.

Scope: every user-visible string in the setup wizard
(`setup_wizard_screen.dart`), the Watching group, Playback and Appearance parts
of `settings_screen.dart`, and `friendly_error.dart`.

Register: neutral Latin American Spanish, informal "tú". Keys and buttons use
"presiona" for hardware keys and "toca" for touch. Spelling uses "video" (not
"vídeo"), "internet", "app".

## Glossary used

| English | Spanish | Note |
|---|---|---|
| Playlist | lista | "Lista M3U", "Archivo de lista". Alone it is vague, so prose says "lista de canales" where the sense is unclear |
| Channel | canal | |
| Movies / Series | Películas / Series | not in this slice, reserved |
| Guide / TV Guide | guía de TV | "EPG" never appears |
| Profile | perfil | |
| Favorites | Favoritos | not in this slice, reserved |
| Settings | Ajustes | matches Android's Spanish UI |
| Provider | proveedor | |
| Link / URL | enlace | prose uses "enlace"; "dirección" for server and guide addresses |
| Backup | copia de seguridad | |
| Nickname (of a playlist) | Nombre | see below |
| Live TV | TV en vivo | |
| Catch-up | diferido | |
| Picture-in-Picture | Imagen en imagen | Android's own wording |
| Accent color | Color de acento | |
| Remote (TV) | mando | "mando a distancia" is longer; understood in Latin America too |

Untouched on purpose: OpenIPTV, IPTV, M3U, Xtream Codes, .m3u/.m3u8, the literal
provider-tag examples `"|EN|"`, `"US|"`, `"A+ -"`.

## Calls where meaning or form changed

| English | Spanish | Why |
|---|---|---|
| Nickname / Nickname (optional) | Nombre / Nombre (opcional) | "Apodo" sounds odd for a playlist. It is only a friendly name. It collides with no other label in this slice |
| Ask to Start Over | Ofrecer ver desde el principio | Literal "Preguntar si empezar de nuevo" is unclear. Describes what the user sees (an offer to watch from the start) |
| Watching (group) | Ver | One short verb for the group heading. Alternatives: "Reproducción" (clashes with Playback), "Para ver" |
| Catch-up channels | "canales que guardan grabaciones (diferido)" | "Catch-up" has no common Spanish term; "diferido" is the closest recognised one |
| Remote Seek Keys | Teclas de avance del mando | "Seek" is jargon; the setting picks which keys jump forward and back |
| Player Transparency "Default" | Predeterminada | Feminine on purpose (agrees with "transparencia"). The Text Size "Default" is masculine ("Predeterminado") |
| Teal | Turquesa | Closest common colour word |
| Welcome to OpenIPTV | Te damos la bienvenida a OpenIPTV | Neutral for any gender; longer than the English |
| Tap Get Started | Toca Empezar | Matches the new button label "Empezar". On a TV it is also shown, but the English has the same "tap" issue |
| Display over other apps | Mostrar sobre otras apps | Android's Latin American wording. Spain's Android says "Superponer sobre otras aplicaciones"; confirm what the owner's devices display |
| Not now | Ahora no | Standard Android wording |
| "Enter {fields} from your provider." | "Escribe {fields} que te dio tu proveedor." | Spanish needs articles on each field ("la dirección…, el nombre de usuario y la contraseña"), so the field names are separate keys that already include the article |
| "ALL-CAPS names into normal capitalization" | "nombres en MAYÚSCULAS a mayúsculas y minúsculas normales" | Direct, but check it reads naturally |
| Solid (transparency) | Sólido | Kept the accent; RAE allows both "sólido" and "solido" |
| Quotes | «…» for quoted UI names | Spanish typographic quotes; the English uses straight quotes |

## Likely too long for the UI (Spanish / English length)

- `wizardRestoreFromBackup` "Restaurar desde una copia de seguridad" (1.8x), a
  text button on the welcome page; suggest "Restaurar copia de seguridad" if it
  wraps.
- `settingsAskStartOverTitle` "Ofrecer ver desde el principio" (1.8x), a settings row title.
- `settingsGroupPlayerControls` (1.7x), `settingsSeekKeysTitle` (1.6x),
  `settingsPlayerTransparencyTitle`, `settingsGuideLayoutTitle` (1.5x): settings
  rows; they have the whole row width, so probably fine except at Extra large text.
- `wizardWelcomeTitle` (two lines, the first 1.7x longer) on a narrow phone at
  large text size.
- `wizardGuideUrlLabel`, `wizardServerAddressLabel`, `wizardNicknameHintFile`
  (1.5x or more): field labels and hints inside text fields; hints are cut off first.
- The Playback row subtitle and all the info tooltips are 1.2 to 1.4x longer;
  they wrap, so check them in the tooltip bubble.
- `wizardFieldUsername` is longer only as part of the "Enter ..." sentence.

## English source strings that should be rewritten or restructured

1. **"You're all set, there!"** The code falls back to the name `'there'` when
   no name is entered (`_firstName`). That is an English-only trick. I added
   `wizardAllSetHeadlineNoName` ("You're all set!" / "¡Todo listo!"); the code
   should use it when the name is empty instead of the word "there".
2. **Missing-field sentence** is built in code by joining English words
   (`'server address'`, `'username'`, `'password'`, `'M3U URL'`) with
   ", " and " and ". I made the nouns separate keys and `wizardListAnd`, but
   the cleaner fix is one message per combination, or a locale-aware list
   formatter (`intl` `ListFormat` is not in Dart's intl yet). Joining with
   ", " in code works for Spanish.
3. **"Tap Get Started"** is wrong on a TV remote; "Press Get Started"/"Choose" or
   just "Use Get Started instead" would be device-neutral.
4. **"Nickname"** is ambiguous; "Playlist name" would be clearer in every language.
5. **"Watching"** as a group title is vague; "Playback and lists" or "Viewing" reads better.
6. **"Start on Boot" / "Start on Wake"** are tech terms; "Open when the TV turns on" /
   "Open when the TV wakes up" are plainer.
7. **"Ask to Start Over"** says "ask" but the setting is about an offer to
   watch from the beginning.
8. The accent swatch names live in `AppTheme.accentSwatches` (`app_theme.dart`)
   as English `label`s and are shown in the picker and as the current value.
   They are keyed here (`settingsAccent*`) but the theme list must hold
   keys/ids, not labels, to be translated.
9. Seconds options are shown as "$v seconds" in code; use the plural key
   `settingsSecondsChoice` (supports "1 second").
10. ICU: apostrophes in English ("Couldn't", "isn't") are fine in gen-l10n
    unless they surround a `{` placeholder; verify when `flutter gen-l10n` first runs.

## In-scope strings not extracted

- Progress messages that `SourceManager.refreshSource(onProgress:)` sends to
  the loading page (they appear under "Setting up your playlist…"). They come
  from the service layer, not the wizard; they need their own keys later.
  `wizardRestoreProgressLine` and `wizardRestoreProgressItem` only carry them.
- Emoji avatars and accent swatches in the wizard have no text.
- `PinField` / `showPinEntryDialog` labels (`lib/shared/widgets/pin_field.dart`)
  and the system picker title come from other files.
- The "Next/Search" keyboard labels are native.
- Car video add-on tile (`CarVideoAddonTile`, in another file) sits inside the
  Playback page and was not done.
- Out of the requested scope but present in the same file, not done: Account,
  Playlists & Guides, About & Advanced groups; Auto-Refresh and Content Sort
  dialogs; "Reset Category Names and Order?" dialog; Channel Lists and TV Guide
  Layout sub-page rows; the Playlists sheet.
- `showAboutDialog` strings (not in Appearance/Playback).
- "Cancel" in the `_ChoiceTile` dialog was extracted (`commonCancel`);
  other copies of "Cancel" in the same file use the same key when converted.
- "Not Now" (capital N) in the permission dialog for Auto-Refresh is outside the
  scope; `commonNotNow` matches the overlay dialog's "Not now".
- `friendlyEpgErrorMessage` and `friendlySourceErrorMessage` return plain
  strings with no context; converting them needs a `BuildContext`/`AppLocalizations`
  parameter.
