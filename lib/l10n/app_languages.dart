import 'package:flutter/widgets.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';

/// Pref value meaning "follow the system language".
const kLanguageAuto = 'auto';

/// How each shipped language is written in its own language, so people can
/// find theirs whatever the app currently shows. Add a line here when a new
/// `app_<tag>.arb` is added (see docs/design/translations.md).
const _nativeNames = <String, String>{
  'en': 'English',
  'es': 'Español',
};

/// Languages offered in the picker (every locale the app ships), English
/// first and the rest alphabetical by native name.
List<Locale> get shippedLanguages {
  final all = [...AppLocalizations.supportedLocales];
  all.sort((a, b) {
    if (a.languageCode == 'en') return -1;
    if (b.languageCode == 'en') return 1;
    return languageName(a).compareTo(languageName(b));
  });
  return all;
}

/// "Español", or the bare tag when a language has no entry yet.
String languageName(Locale l) => _nativeNames[l.toLanguageTag()] ??
    _nativeNames[l.languageCode] ??
    l.toLanguageTag();

/// The locale to force on the app for a stored [pref], or null for 'auto' —
/// with no forced locale Flutter picks the best shipped match for the
/// system's language list and follows later system changes by itself.
/// A tag we don't ship resolves to English.
Locale? localeForPref(String pref) {
  if (pref == kLanguageAuto) return null;
  final parts = pref.split('-');
  final wanted = Locale(parts.first, parts.length > 1 ? parts[1] : null);
  final supported = AppLocalizations.supportedLocales;
  for (final l in supported) {
    if (l == wanted) return l;
  }
  for (final l in supported) {
    if (l.languageCode == wanted.languageCode) return l;
  }
  return const Locale('en');
}
