import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

void main() {
  late int taps;
  late int longPresses;

  Future<void> pump(WidgetTester tester) async {
    taps = 0;
    longPresses = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TvFocusable(
          autofocus: true,
          wrapsGesture: false,
          onTap: () => taps++,
          onLongPress: () => longPresses++,
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('a short OK press taps', (tester) async {
    await pump(tester);
    await simulateKeyDownEvent(LogicalKeyboardKey.select);
    await simulateKeyUpEvent(LogicalKeyboardKey.select);
    expect((taps, longPresses), (1, 0));
  });

  testWidgets('holding OK past the timer long-presses once', (tester) async {
    await pump(tester);
    await simulateKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    await simulateKeyUpEvent(LogicalKeyboardKey.select);
    expect((taps, longPresses), (0, 1));
  });

  testWidgets('the platform key repeat counts as the long-press',
      (tester) async {
    await pump(tester);
    await simulateKeyDownEvent(LogicalKeyboardKey.select);
    await simulateKeyRepeatEvent(LogicalKeyboardKey.select);
    await simulateKeyRepeatEvent(LogicalKeyboardKey.select);
    await simulateKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    expect((taps, longPresses), (0, 1));
  });

  testWidgets(
      'holding OK to open a sheet does not click its autofocused option',
      (tester) async {
    var removed = 0;
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      shortcuts: appShortcuts,
      home: Scaffold(
        body: TvFocusable(
          key: key,
          autofocus: true,
          wrapsGesture: false,
          onTap: () {},
          onLongPress: () => showModalBottomSheet<void>(
            context: key.currentContext!,
            builder: (_) => ListTile(
              autofocus: true,
              title: const Text('Remove'),
              onTap: () => removed++,
            ),
          ),
          child: const SizedBox(width: 100, height: 100),
        ),
      ),
    ));
    await tester.pump();
    await simulateKeyDownEvent(LogicalKeyboardKey.select);
    await simulateKeyRepeatEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('Remove'), findsOneWidget);
    // The remote keeps repeating until OK is let go.
    await simulateKeyRepeatEvent(LogicalKeyboardKey.select);
    await simulateKeyRepeatEvent(LogicalKeyboardKey.select);
    await simulateKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(removed, 0);
    // A fresh press still picks it.
    await simulateKeyDownEvent(LogicalKeyboardKey.select);
    await simulateKeyUpEvent(LogicalKeyboardKey.select);
    expect(removed, 1);
  });
}
