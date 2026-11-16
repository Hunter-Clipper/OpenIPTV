import 'package:flutter/material.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/theme/guide_style.dart';
import 'package:open_iptv/shared/utils/genre_colors.dart';

/// Retro Cable (#178): a deep-blue, flat, chunky look in the spirit of old
/// cable-box guides: blue panels, a cream channel column, bold rounded type,
/// colour-coded programme cells, a white block for the focus. Only the feel
/// is borrowed; no brand names, logos or artwork.
class RetroCable {
  RetroCable._();

  static const fontFamily = 'Nunito';

  static const navy = Color(0xFF0A2268); // the page
  static const panel = Color(0xFF123C9C); // cards, sheets
  static const panelHigh = Color(0xFF1B4DC0); // inputs, chips
  static const edge = Color(0xFF5B7FD6); // outlines
  static const cream = Color(0xFFEDE6C9); // channel column
  static const yellow = Color(0xFFFFE066); // titles, selection
  static const text = Color(0xFFF6F8FF);
  static const textDim = Color(0xFFC6D4F6);
  static const error = Color(0xFFFF8A80);

  // Programme cell colours.
  static const cellBlue = Color(0xFF2452BD);
  static const sportsGreen = Color(0xFF2E8B3E);
  static const moviePurple = Color(0xFF6B34B0);
  static const kidsYellow = Color(0xFFE6D24A);
  static const newsBlue = Color(0xFF1F6FB8);

  static const guide = GuideStyle(
    cellColor: cellBlue,
    cellText: text,
    genreColors: {
      GenreBucket.sports: (fill: sportsGreen, text: Colors.white),
      GenreBucket.movies: (fill: moviePurple, text: Colors.white),
      GenreBucket.kids: (fill: kidsYellow, text: Color(0xFF1B1B00)),
      GenreBucket.news: (fill: newsBlue, text: Colors.white),
    },
    focusFill: Colors.white,
    focusText: navy,
    channelColumn: cream,
    channelText: navy,
    headerGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2F63D8), Color(0xFF0E3590)],
    ),
    headerText: text,
    titleColor: yellow,
    nowColor: yellow,
  );

  /// The whole app's theme: the normal component styling, re-coloured and
  /// re-typed, with square-ish corners.
  static ThemeData theme() {
    final base = AppTheme.dark(yellow);
    TextStyle chunky(TextStyle? s, {FontWeight? weight}) => (s ?? const TextStyle())
        .copyWith(fontFamily: fontFamily, fontWeight: weight ?? s?.fontWeight);
    const surfaceLow = Color(0xFF0E2D80);
    final scheme = base.colorScheme.copyWith(
      primary: yellow,
      onPrimary: navy,
      secondary: yellow,
      onSecondary: navy,
      surface: panel,
      onSurface: text,
      onSurfaceVariant: textDim,
      surfaceDim: navy,
      surfaceBright: panelHigh,
      surfaceContainerLowest: navy,
      surfaceContainerLow: surfaceLow,
      surfaceContainer: panel,
      surfaceContainerHigh: panelHigh,
      surfaceContainerHighest: panelHigh,
      outline: edge,
      outlineVariant: panelHigh,
      inverseSurface: cream,
      onInverseSurface: navy,
      error: error,
      onError: navy,
    );
    final t = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: text,
      displayColor: text,
    );
    // Bold where the normal look is semi-bold: Nunito ships Regular and Bold.
    TextStyle? bold(TextStyle? s) => s == null
        ? null
        : s.copyWith(
            fontWeight: (s.fontWeight ?? FontWeight.w400).value >= 500
                ? FontWeight.w700
                : s.fontWeight);
    final textTheme = t.copyWith(
      displaySmall: bold(t.displaySmall),
      headlineLarge: bold(t.headlineLarge),
      headlineMedium: bold(t.headlineMedium),
      headlineSmall: bold(t.headlineSmall),
      titleLarge: bold(t.titleLarge)?.copyWith(color: yellow),
      titleMedium: bold(t.titleMedium),
      titleSmall: bold(t.titleSmall),
      labelLarge: bold(t.labelLarge)?.copyWith(color: yellow),
      labelMedium: bold(t.labelMedium),
      labelSmall: bold(t.labelSmall),
      bodySmall: t.bodySmall?.copyWith(color: textDim),
    );
    const flat = 4.0;
    RoundedRectangleBorder shape([double r = flat]) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
    return base.copyWith(
      scaffoldBackgroundColor: navy,
      colorScheme: scheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: const IconThemeData(color: textDim),
      focusColor: Colors.white.withValues(alpha: 0.30),
      dividerTheme: const DividerThemeData(color: edge, thickness: 0.6),
      listTileTheme: const ListTileThemeData(
        iconColor: textDim,
        textColor: text,
        tileColor: Colors.transparent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: navy,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: chunky(textTheme.titleLarge, weight: FontWeight.w700),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: panel,
        indicatorColor: yellow.withValues(alpha: 0.28),
        indicatorShape: shape(flat),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? yellow : textDim,
            size: 24)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: s.contains(WidgetState.selected) ? text : textDim)),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: shape(),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: panelHigh,
        selectedColor: yellow.withValues(alpha: 0.30),
        labelStyle:
            const TextStyle(fontFamily: fontFamily, color: text, fontSize: 13),
        shape: shape(),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: panelHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(flat),
          borderSide: const BorderSide(color: edge),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(flat),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        hintStyle: const TextStyle(fontFamily: fontFamily, color: textDim),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: shape(),
        titleTextStyle: const TextStyle(
            fontFamily: fontFamily,
            color: yellow,
            fontSize: 18,
            fontWeight: FontWeight.w700),
        contentTextStyle: const TextStyle(
            fontFamily: fontFamily, color: text, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panelHigh,
        contentTextStyle:
            const TextStyle(fontFamily: fontFamily, color: text),
        actionTextColor: yellow,
        behavior: SnackBarBehavior.floating,
        shape: shape(),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: yellow,
        linearTrackColor: Colors.white.withValues(alpha: 0.2),
        circularTrackColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: base.filledButtonTheme.style?.copyWith(
          shape: WidgetStatePropertyAll(shape()),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: base.textButtonTheme.style?.copyWith(
          foregroundColor: const WidgetStatePropertyAll(text),
          shape: WidgetStatePropertyAll(shape()),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: base.outlinedButtonTheme.style?.copyWith(
          foregroundColor: const WidgetStatePropertyAll(text),
          side: const WidgetStatePropertyAll(BorderSide(color: edge)),
          shape: WidgetStatePropertyAll(shape()),
          textStyle: const WidgetStatePropertyAll(
              TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w700)),
        ),
      ),
      extensions: const [guide],
    );
  }
}
