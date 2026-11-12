import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/l10n/app_languages.dart';

void main() {
  test('auto forces no locale so Flutter follows the system', () {
    expect(localeForPref('auto'), isNull);
  });

  test('a shipped tag resolves to itself', () {
    expect(localeForPref('es'), const Locale('es'));
    expect(localeForPref('en'), const Locale('en'));
  });

  test('a regional tag falls back to its language', () {
    expect(localeForPref('es-MX'), const Locale('es'));
  });

  test('a language we do not ship resolves to English', () {
    expect(localeForPref('xx'), const Locale('en'));
    expect(localeForPref('ja'), const Locale('en'));
  });

  test('picker lists English first and every shipped language by name', () {
    final langs = shippedLanguages;
    expect(langs.first.languageCode, 'en');
    expect(langs.map(languageName), containsAll(['English', 'Español']));
  });
}
