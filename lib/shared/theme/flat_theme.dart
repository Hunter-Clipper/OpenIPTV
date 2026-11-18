import 'package:material_ui/material_ui.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/theme/guide_style.dart';

/// The colours, type and corner size of a "flat" look (Retro Cable, Terminal
/// green, Amber; #178). [buildFlatTheme] turns one into a whole-app theme.
@immutable
class FlatPalette {
  const FlatPalette({
    required this.fontFamily,
    required this.background,
    required this.panel,
    required this.panelLow,
    required this.panelHigh,
    required this.edge,
    required this.text,
    required this.textDim,
    required this.primary,
    required this.onPrimary,
    required this.title,
    required this.error,
    this.guide,
    this.radius = 4,
    this.brightness = Brightness.dark,
    this.boldenText = true,
  });

  final String fontFamily;

  /// The page; cards and sheets; the quieter and the brighter panels.
  final Color background;
  final Color panel;
  final Color panelLow;
  final Color panelHigh;

  /// Outlines and dividers.
  final Color edge;
  final Color text;
  final Color textDim;

  /// Highlights and selection, and the text on them.
  final Color primary;
  final Color onPrimary;

  /// Page and dialog titles.
  final Color title;
  final Color error;
  /// The TV guide's own style, for looks that have one.
  final GuideStyle? guide;
  final double radius;
  final Brightness brightness;

  /// Turns semi-bold text bold (for fonts that ship only Regular and Bold).
  final bool boldenText;
}

/// A whole-app theme from [p]: the normal component styling, re-coloured and
/// re-typed, with small corners.
ThemeData buildFlatTheme(FlatPalette p) {
  final fontFamily = p.fontFamily;
  final base = AppTheme.dark(p.primary);
  final scheme = base.colorScheme.copyWith(
    brightness: p.brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    secondary: p.primary,
    onSecondary: p.onPrimary,
    surface: p.panel,
    onSurface: p.text,
    onSurfaceVariant: p.textDim,
    surfaceDim: p.background,
    surfaceBright: p.panelHigh,
    surfaceContainerLowest: p.background,
    surfaceContainerLow: p.panelLow,
    surfaceContainer: p.panel,
    surfaceContainerHigh: p.panelHigh,
    surfaceContainerHighest: p.panelHigh,
    outline: p.edge,
    outlineVariant: p.panelHigh,
    inverseSurface: p.text,
    onInverseSurface: p.background,
    error: p.error,
    onError: p.background,
  );
  final t = base.textTheme.apply(
    fontFamily: fontFamily,
    bodyColor: p.text,
    displayColor: p.text,
  );
  // Bold where the normal look is semi-bold: these fonts ship Regular and Bold.
  TextStyle? bold(TextStyle? s) => s == null || !p.boldenText
      ? s
      : s.copyWith(
          fontWeight: (s.fontWeight ?? FontWeight.w400).value >= 500
              ? FontWeight.w700
              : s.fontWeight);
  final textTheme = t.copyWith(
    displaySmall: bold(t.displaySmall),
    headlineLarge: bold(t.headlineLarge),
    headlineMedium: bold(t.headlineMedium),
    headlineSmall: bold(t.headlineSmall),
    titleLarge: bold(t.titleLarge)?.copyWith(color: p.title),
    titleMedium: bold(t.titleMedium),
    titleSmall: bold(t.titleSmall),
    labelLarge: bold(t.labelLarge)?.copyWith(color: p.title),
    labelMedium: bold(t.labelMedium),
    labelSmall: bold(t.labelSmall),
    bodySmall: t.bodySmall?.copyWith(color: p.textDim),
  );
  RoundedRectangleBorder shape() =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.radius));
  TextStyle label(Color c, {double size = 14, FontWeight? w}) =>
      TextStyle(fontFamily: fontFamily, color: c, fontSize: size, fontWeight: w);
  final buttonText = WidgetStatePropertyAll(
      TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700));
  return base.copyWith(
    scaffoldBackgroundColor: p.background,
    colorScheme: scheme,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    iconTheme: IconThemeData(color: p.textDim),
    focusColor: p.primary.withValues(alpha: 0.30),
    dividerTheme: DividerThemeData(color: p.edge, thickness: 0.6),
    listTileTheme: ListTileThemeData(
      iconColor: p.textDim,
      textColor: p.text,
      tileColor: Colors.transparent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: (textTheme.titleLarge ?? const TextStyle())
          .copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: p.panel,
      indicatorColor: p.primary.withValues(alpha: 0.28),
      indicatorShape: shape(),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? p.primary : p.textDim,
          size: 24)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => label(
          s.contains(WidgetState.selected) ? p.text : p.textDim,
          size: 12,
          w: FontWeight.w700)),
    ),
    cardTheme: CardThemeData(color: p.panel, elevation: 0, shape: shape()),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: p.panelHigh,
      selectedColor: p.primary.withValues(alpha: 0.30),
      labelStyle: label(p.text, size: 13),
      shape: shape(),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      fillColor: p.panelHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(p.radius),
        borderSide: BorderSide(color: p.edge),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(p.radius),
        borderSide: BorderSide(color: p.primary, width: 2),
      ),
      hintStyle: label(p.textDim),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.panel,
      surfaceTintColor: Colors.transparent,
      shape: shape(),
      titleTextStyle: label(p.title, size: 18, w: FontWeight.w700),
      contentTextStyle: label(p.text),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.panelHigh,
      contentTextStyle: label(p.text),
      actionTextColor: p.primary,
      behavior: SnackBarBehavior.floating,
      shape: shape(),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.primary,
      linearTrackColor: p.text.withValues(alpha: 0.2),
      circularTrackColor: Colors.transparent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        shape: WidgetStatePropertyAll(shape()),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.copyWith(
        foregroundColor: WidgetStatePropertyAll(p.text),
        shape: WidgetStatePropertyAll(shape()),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(
        foregroundColor: WidgetStatePropertyAll(p.text),
        side: WidgetStatePropertyAll(BorderSide(color: p.edge)),
        shape: WidgetStatePropertyAll(shape()),
        textStyle: buttonText,
      ),
    ),
    extensions: [if (p.guide != null) p.guide!],
  );
}
