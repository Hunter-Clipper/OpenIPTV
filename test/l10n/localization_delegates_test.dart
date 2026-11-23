import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_iptv/l10n/app_languages.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';

/// The bottom navigation bar crashed for people whose language was not
/// English (anonymous crash reports, 0.15.1 onward): the delegates gave the
/// widgets no `MaterialLocalizations` of the type material_ui reads.
void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('NavigationBar builds in ${locale.languageCode}', (t) async {
      await t.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'A'),
                NavigationDestination(icon: Icon(Icons.search), label: 'B'),
              ],
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  }
}
