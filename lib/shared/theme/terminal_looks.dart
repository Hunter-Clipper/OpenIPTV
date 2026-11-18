import 'package:material_ui/material_ui.dart';
import 'package:open_iptv/shared/theme/flat_theme.dart';
import 'package:open_iptv/shared/theme/guide_style.dart';

/// Terminal green and Amber (#178): pure black with one phosphor colour for
/// everything, a monospace font, programmes as outlines, and a solid inverse
/// block under the remote, like a selection in a terminal.
class TerminalLooks {
  TerminalLooks._();

  static const fontFamily = 'JetBrainsMono';

  static ThemeData green() => _build(
        text: const Color(0xFF3DFF7F),
        dim: const Color(0xFF2BB35E),
        edge: const Color(0xFF1F7A45),
        panel: const Color(0xFF04100A),
        high: const Color(0xFF0A2214),
        wash: const Color(0x663DFF7F),
        codeLoader: true,
      );

  static ThemeData amber() => _build(
        text: const Color(0xFFFFB000),
        dim: const Color(0xFFB88000),
        edge: const Color(0xFF7A5600),
        panel: const Color(0xFF120C02),
        high: const Color(0xFF241804),
        wash: const Color(0x66FFB000),
        amberLoader: true,
      );

  static ThemeData _build({
    required Color text,
    required Color dim,
    required Color edge,
    required Color panel,
    required Color high,
    required Color wash,
    bool codeLoader = false,
    bool amberLoader = false,
  }) {
    const black = Color(0xFF000000);
    final guide = GuideStyle(
      cellColor: black,
      cellText: text,
      genreColors: const {},
      focusFill: text,
      focusText: black,
      channelColumn: black,
      channelText: text,
      headerGradient: const LinearGradient(colors: [black, black]),
      headerText: text,
      titleColor: text,
      nowColor: text,
      // Logos sit bare, lit by a wash of the phosphor colour so dark ones
      // show on black.
      logoShadow: wash,
      outlined: true,
      outlineColor: edge,
      airingOutline: text,
      codeLoader: codeLoader,
      amberLoader: amberLoader,
    );
    return buildFlatTheme(FlatPalette(
      fontFamily: fontFamily,
      background: black,
      panel: panel,
      panelLow: black,
      panelHigh: high,
      edge: edge,
      text: text,
      textDim: dim,
      primary: text,
      onPrimary: black,
      title: text,
      error: const Color(0xFFFF6B6B),
      guide: guide,
      radius: 2,
    ));
  }
}
