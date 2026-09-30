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
}
