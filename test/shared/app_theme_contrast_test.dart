import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('labels on every accent swatch and on error reach 4.5:1', () {
    for (final s in AppTheme.accentSwatches) {
      expect(_ratio(AppTheme.onAccent(s.color), s.color), greaterThanOrEqualTo(4.5),
          reason: s.label);
    }
    expect(_ratio(AppTheme.onAccent(const Color(0xFFFF453A)),
            const Color(0xFFFF453A)),
        greaterThanOrEqualTo(4.5));
  });

  test('the theme uses it for filled buttons and primary', () {
    for (final s in AppTheme.accentSwatches) {
      final t = AppTheme.dark(s.color);
      expect(t.colorScheme.onPrimary, AppTheme.onAccent(s.color));
    }
  });

  test('secondary text reaches 4.5:1 on every surface it sits on', () {
    final t = AppTheme.dark();
    final muted = t.colorScheme.onSurfaceVariant;
    for (final bg in [
      AppTheme.backgroundColor,
      AppTheme.surfaceColor,
      AppTheme.surfaceVariantColor,
    ]) {
      expect(_ratio(muted, bg), greaterThanOrEqualTo(4.5));
    }
  });
}
