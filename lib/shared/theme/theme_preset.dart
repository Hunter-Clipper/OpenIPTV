import 'package:flutter/material.dart';

/// The looks the app can wear (#178). Chosen per profile, next to the accent
/// colour. Presets that fix their own colours ([fixedColours]) ignore the
/// accent; the others tint their highlights with it.
enum ThemePreset {
  /// The app's normal dark look.
  standard(id: 'standard'),

  /// Pure black backgrounds for OLED screens; otherwise like [standard].
  trueBlack(id: 'trueBlack', background: Color(0xFF000000)),

  /// Deep blue, flat and chunky, in the spirit of old cable-box guides.
  retroCable(id: 'retroCable', fixedColours: true),

  /// Near-white and cool; the accent colour still applies.
  light(id: 'light'),

  /// Black with green phosphor text, outlined cells, a monospace font.
  terminalGreen(id: 'terminalGreen', fixedColours: true),

  /// Black with amber phosphor text, like an old monitor.
  amber(id: 'amber', fixedColours: true);

  const ThemePreset(
      {required this.id, this.background, this.fixedColours = false});

  /// What is stored in a profile and in backups.
  final String id;

  /// Replaces the page background, or null to keep the normal one.
  final Color? background;

  /// Whether the preset owns all its colours (so the accent is ignored).
  final bool fixedColours;

  static ThemePreset fromId(String? id) => values.firstWhere(
        (p) => p.id == id,
        orElse: () => ThemePreset.standard,
      );
}
