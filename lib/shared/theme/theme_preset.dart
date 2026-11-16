import 'package:flutter/material.dart';

/// The looks the app can wear (#178). Chosen per profile, next to the accent
/// colour. Presets that fix their own colours ([fixedColours]) ignore the
/// accent; the others tint their highlights with it.
enum ThemePreset {
  /// The app's normal dark look.
  standard(id: 'standard'),

  /// Pure black backgrounds for OLED screens; otherwise like [standard].
  trueBlack(id: 'trueBlack', background: Color(0xFF000000));

  const ThemePreset({required this.id, this.background});

  /// What is stored in a profile and in backups.
  final String id;

  /// Replaces the page background, or null to keep the normal one.
  final Color? background;

  /// Whether the preset owns all its colours (so the accent is ignored).
  /// None of today's presets do; the retro presets will.
  bool get fixedColours => false;

  static ThemePreset fromId(String? id) => values.firstWhere(
        (p) => p.id == id,
        orElse: () => ThemePreset.standard,
      );
}
