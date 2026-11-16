import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/theme/theme_preset.dart';

void main() {
  test('ids round-trip and unknown ids fall back to Standard', () {
    for (final p in ThemePreset.values) {
      expect(ThemePreset.fromId(p.id), p);
    }
    expect(ThemePreset.fromId('nope'), ThemePreset.standard);
    expect(ThemePreset.fromId(null), ThemePreset.standard);
  });

  test('True black makes the page and bars pure black, keeps the accent', () {
    const accent = Color(0xFFFF9500);
    final std = AppTheme.forPreset(ThemePreset.standard, accent);
    final black = AppTheme.forPreset(ThemePreset.trueBlack, accent);
    expect(black.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(black.appBarTheme.backgroundColor, const Color(0xFF000000));
    expect(black.colorScheme.primary, accent);
    expect(std.scaffoldBackgroundColor, isNot(const Color(0xFF000000)));
    expect(std.colorScheme.primary, accent);
  });

  test('a profile starts on Standard and copyWith changes only the theme', () {
    final now = DateTime(2026, 1, 1);
    final p = Profile(
        id: 'a', name: 'A', avatarEmoji: 'x', createdAt: now, updatedAt: now);
    expect(p.themeId, 'standard');
    final q = p.copyWith(themeId: ThemePreset.trueBlack.id);
    expect(q.themeId, 'trueBlack');
    expect(q.accentColor, p.accentColor);
  });
}
