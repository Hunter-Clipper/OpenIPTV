import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/theme/guide_style.dart';
import 'package:open_iptv/shared/theme/theme_preset.dart';

void main() {
  _retroTests();
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

void _retroTests() {
  test('Retro Cable owns its colours and brings a guide style', () {
    expect(ThemePreset.retroCable.fixedColours, isTrue);
    expect(ThemePreset.standard.fixedColours, isFalse);
    final retro =
        AppTheme.forPreset(ThemePreset.retroCable, const Color(0xFFFF0000));
    // The accent is ignored: highlights are the look's own yellow.
    expect(retro.colorScheme.primary, const Color(0xFFFFE066));
    expect(retro.textTheme.bodyMedium!.fontFamily, 'Nunito');
    expect(retro.extension<GuideStyle>(), isNotNull);
    final std = AppTheme.forPreset(ThemePreset.standard);
    expect(std.extension<GuideStyle>(), isNull);
  });
}
