# Spanish consistency review

Pass over `lib/l10n/app_es.arb` (1010 strings, seven translators) to make one
voice: neutral Latin American Spanish, informal "tú", sentence case. Only
`app_es.arb` changed (63 strings); keys and placeholders are untouched.

## Glossary decisions

| Topic | Decision | Why |
|---|---|---|
| Add | **Agregar** everywhere (was a mix with Añadir) | Agregar is the usual Latin American verb; "añadir" reads as Spain. Majority of UI strings already used it |
| Delete / remove / clear | **Eliminar** = delete a stored thing for good (playlist, profile, VPN profile, pending reports). **Quitar** = take out of a list or row (favorites, recents, locked list, extra guide, PIN, multi-view tile). **Borrar** = clear data or history (guide data, search history, progress) | Applied by meaning |
| Type | **Escribe** (no Ingresa/Introduce anywhere) | Already consistent |
| Press / tap | **Presiona** for remote keys (OK, Atrás), **Toca** only in touch-only hints (multi-view accessibility hints), **Selecciona** where one string covers phone and TV, **mantén presionado** for hold OK / long-press | A remote has no "toca" |
| Try again | **Reintentar** for buttons; "inténtalo de nuevo" stays in sentences | Short button label |
| Power User Tools | **Herramientas avanzadas** everywhere | |
| Settings group "Watching" | **Visualización** (was "Ver") | "Reproducción" is already the Playback page; "Ver" was a bare verb |
| Catch-up | **diferido** | Kept, now the only term |
| Go live / Watch live | **Ver en vivo** both | Natural; "Ir al vivo" was jargon. "en directo" (Spain) replaced by "en vivo" |
| Cast | **Transmitir** ("Dejar de transmitir"); a stream stays **transmisión** | Stop-casting no longer reads like stopping the stream |
| TV set | **televisor** in prose ("TV" only in "TV en vivo", "guía de TV") | Was "TV", "TVs" and "televisor" mixed |
| Off / On | Toggle states are masculine **Activado / Desactivado**; the VPN status is feminine to agree with "Conectada" (**Desconectada**); every "Default" is **Predeterminado** | Was Desactivada/Predeterminada in places |
| Units | "1 h 5 min", "hace 3 s", "20 %" | One style; percent now with a space in both download strings |
| Failures | **falla(s)** instead of "fallo(s)" | Latin American |
| Reliable | **confiable** instead of "fiable" | Latin American |
| Quotes | «…» for UI names | |
| Ellipsis | "…" (one character), not "..." | |

## Cross-references aligned

Every string that names another screen or button was checked against the actual label in this file.

| In string | Quotes | Actual label |
|---|---|---|
| `liveTvChannelHidden` | Ajustes → **Visualización** → Listas de canales → Canales ocultos | `settingsGroupWatching`, `settingsChannelListsTitle`, `settingsHiddenChannelsTitle` (Ver changed to Visualización) |
| `settingsHiddenChannelsBody` | Ocultar canal | `liveTvHideChannel` (the "hold OK or long-press" wording is now "mantén presionado un canal") |
| `extraGuidesFillDescription`, `extraGuidesLinksEmpty` | Cambiar guía | `changeGuideTitle`, `liveTvChangeGuide` |
| `changeGuideNoGuidesBody` | Ajustes → Listas y guías → Guías adicionales | `settingsGroupPlaylistsGuides`, `settingsExtraGuidesTitle` |
| `extraGuidesModeOptimisticDesc` | Revisar coincidencias de guía | `extraGuidesReviewMatchesTitle` (already equal) |
| `settingsSortOrderBody` | Orden del proveedor | `settingsSortProvider` (equal) |
| `powerUserOvpnAuthFailed` | Cambiar el acceso de OpenVPN | `powerUserChangeOvpnLogin` (equal) |
| `playerNoticePassthrough`, `playerNoticeTunneled` | Herramientas avanzadas (was "las Herramientas avanzadas"); passthrough now says "sonido envolvente sin procesar" like its setting title | `settingsPowerToolsTitle`, `powerUserPassthroughTitle` |
| `updatePermissionBody` / `carVideoNeedsPermission` | Permitir desde esta fuente (car one said "de") | one phrase for both |
| `wizardRestoreEmpty` | now "Usa Empezar en su lugar" (was "Toca Empezar") | `wizardGetStarted` |
| `settingsPlaybackSubtitle` | Empezar de nuevo | `playerStartOver` and the renamed `settingsAskStartOverTitle` |
| `errorGuideLogin`, `errorGuideInvalidLink` | "dirección de la guía" | field label `wizardGuideUrlLabel` |
| `detailRemoveFromContinueWatching` | Quitar de Continuar viendo | `detailContinueWatching` (was "Seguir viendo" vs "Continuar viendo") |

## Strings shortened or reworded for length (English | before | after)

| English | Before | After |
|---|---|---|
| Restore from a backup | Restaurar desde una copia de seguridad | Restaurar copia de seguridad |
| TV Guide URL (optional) | Enlace de la guía de TV (opcional) | Dirección de la guía (opcional) |
| Ask to Start Over | Ofrecer ver desde el principio | Ofrecer empezar de nuevo |
| LIVE (player badge) | EN VIVO | VIVO |
| LIVE (guide panel badge) | EN VIVO | VIVO |
| Live (channel card badge) | En vivo | Vivo |
| On now | Ahora en emisión | En emisión |
| Go live | Ir al vivo | Ver en vivo |
| Stop casting | Detener transmisión | Dejar de transmitir |
| Remove from Continue Watching | Quitar de Seguir viendo | Quitar de Continuar viendo |
| Remove from Favorites (player) | Quitar de Favoritos | Quitar de favoritos |

Left as is on purpose: "TV en vivo" (nav label, 7 vs 7 chars), "Copia de seguridad y restauración" (row title, wraps), "Ver desde el principio" (button, only 1.0x).

## Other wording fixes

Añadir/Añade/añadida to Agregar/Agrega/agregada (about 10 strings); "en directo" to "en vivo" (2); "..." to "…" (1); "fiable" to "confiable" (2); "fallos" to "fallas" (3); "Desactivada" to "Desactivado" (2); "Predeterminada" to "Predeterminado" (1); "Quitar" to "Eliminar" for the VPN profile (4); "se borrarán" to "se eliminarán" (profile); TV/TVs to televisor (3 cast strings); "justo ahora" to "hace un momento"; "Selecciona una dirección para copiarla" (was "Toca"). Punctuation (¿?¡!) was checked by script: all pairs balanced. ICU plurals in the file all use `=1{…} other{…}`; unchanged. `flutter gen-l10n` and `flutter test -j 1 test/l10n` pass.

## 15 strings a native speaker should still double check

1. `playerLiveBadge` / `epgPanelLiveBadge` "VIVO" and `liveTvLiveBadge` "Vivo": shortened from "EN VIVO"; may look odd to some readers, "EN VIVO" is the safe fallback if space allows.
2. `settingsGroupWatching` "Visualización": new group name, a bit formal.
3. `settingsAskStartOverTitle` "Ofrecer empezar de nuevo" and its body.
4. `catchupWatchLive` / `playerGoLive` "Ver en vivo" (replaces "Ir al vivo").
5. "diferido" (catch-up) in `liveTvCatchupAvailable`, `epgPanelCatchupUnavailable`, `guideDataDaysDescription`, `settingsAskStartOverBody`: is it understood without explanation?
6. `castStop` "Dejar de transmitir" and `castFailedChannel` "Deja de transmitir para verlo aquí".
7. "altavoces" (`castSearching`): Mexico says "bocinas", Argentina "parlantes".
8. `powerUserPassthroughTitle` "Sonido envolvente sin procesar" and its description.
9. `powerUserTunnelingTitle` "Reproducción en túnel" (technical).
10. `powerUserUaTitle` "Agente de usuario" (user agent) and description.
11. `extraGuidesModeExplicit`/`Optimistic` "Explícito" / "Optimista" and their descriptions.
12. `extraGuidesFillDescription`: the sentence with the wink and "XMLTV EPG".
13. `consentBody`, `reportsIntro`, `reportsNeverList`: privacy text, only polished wording ("fallas"); meaning must stay exact.
14. `settingsOverlayDialogTitle` "Permitir mostrar sobre otras apps" and the Android permission names «Mostrar sobre otras apps» / «Permitir desde esta fuente» (match the devices' Spanish settings screens).
15. `settingsHiddenChannelsBody` / `extraGuidesLinksEmpty`: "mantén presionado un canal" stands for hold OK on TV and long-press on phone.
