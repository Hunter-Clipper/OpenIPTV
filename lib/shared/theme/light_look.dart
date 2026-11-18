import 'package:material_ui/material_ui.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/theme/flat_theme.dart';

/// The Light look (#178): near-white and cool, the normal shapes and font,
/// with the profile's accent colour as the highlight.
class LightLook {
  LightLook._();

  static ThemeData theme([Color? accent]) {
    final primary = accent ?? AppTheme.defaultAccent;
    return buildFlatTheme(FlatPalette(
      fontFamily: AppTheme.fontFamily,
      background: const Color(0xFFF5F7FA),
      panel: const Color(0xFFFFFFFF),
      panelLow: const Color(0xFFF0F2F6),
      panelHigh: const Color(0xFFE6EAF0),
      edge: const Color(0xFFB9C1CC),
      text: const Color(0xFF14171C),
      textDim: const Color(0xFF566070),
      primary: primary,
      onPrimary: AppTheme.onAccent(primary),
      title: const Color(0xFF14171C),
      error: const Color(0xFFC62828),
      brightness: Brightness.light,
      boldenText: false,
      radius: 12,
    ));
  }
}
