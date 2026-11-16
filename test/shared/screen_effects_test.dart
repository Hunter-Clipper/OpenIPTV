import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/shared/theme/screen_effects.dart';

void main() {
  test('everything is off by default and copyWith changes one thing', () {
    const fx = ScreenEffects();
    expect(fx.any, isFalse);
    expect(fx.copyWith(glow: true).any, isTrue);
    expect(fx.copyWith(lines: true).strength, CrtStrength.medium);
    expect(fx.copyWith(flicker: true).lines, isFalse);
  });

  test('strengths round-trip by id and unknown ids fall back to Medium', () {
    for (final s in CrtStrength.values) {
      expect(CrtStrength.fromId(s.id), s);
    }
    expect(CrtStrength.fromId('x'), CrtStrength.medium);
    expect(CrtStrength.light.alpha < CrtStrength.medium.alpha, isTrue);
    expect(CrtStrength.medium.alpha < CrtStrength.strong.alpha, isTrue);
  });

  testWidgets('with nothing on, the child is returned untouched',
      (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: ScreenEffectsOverlay(
          effects: ScreenEffects(), child: Text('hi')),
    ));
    expect(find.byType(CustomPaint), findsNothing);
    expect(find.text('hi'), findsOneWidget);
  });

  testWidgets('lines are drawn over the child and never take touches',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScreenEffectsOverlay(
          effects: const ScreenEffects(lines: true, glow: true),
          child: Center(
              child: GestureDetector(
                  onTap: () => taps++, child: const Text('tap me'))),
        ),
      ),
    ));
    expect(find.byType(IgnorePointer), findsWidgets);
    await tester.tap(find.text('tap me'));
    expect(taps, 1);
  });
}
