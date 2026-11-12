import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/widgets/empty_state_view.dart';
import 'package:open_iptv/shared/widgets/error_state_view.dart';
import 'package:open_iptv/shared/widgets/settings_group.dart';
import 'package:open_iptv/telemetry/consent_dialog.dart';

/// 320 dp wide at 200% text: nothing may overflow or clip (WCAG 1.4.4 / 1.4.10).
Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(ProviderScope(child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.dark(),
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
      child: c!,
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  )));
  await tester.pump();
}

void main() {
  testWidgets('empty state holds up', (tester) async {
    await _pump(
        tester,
        EmptyStateView(
          icon: Icons.live_tv,
          title: 'No channels yet',
          message: 'Add a playlist to see your channels here.',
          actionLabel: 'Add a playlist',
          onAction: () {},
        ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('error state holds up', (tester) async {
    await _pump(
        tester,
        ErrorStateView(
          message: "The provider's server is having trouble. Try again soon.",
          onRetry: () {},
        ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings group with a long row holds up', (tester) async {
    await _pump(
        tester,
        SettingsGroup(
          title: 'Playback',
          description: 'Choose how video plays on this device.',
          children: [
            SwitchListTile(
              secondary: const IconBadge(icon: Icons.speed_rounded),
              title: const Text('Match Frame Rate'),
              value: true,
              onChanged: (_) {},
            ),
          ],
        ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the anonymous-reports question holds up', (tester) async {
    await _pump(
        tester,
        Builder(
            builder: (context) => FilledButton(
                onPressed: () => askStatsConsentOnce(
                    context, ProviderScope.containerOf(context)),
                child: const Text('open'))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Help improve OpenIPTV?'), findsOneWidget);
    expect(find.text('No Thanks'), findsOneWidget);
    expect(find.text('Turn On'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
