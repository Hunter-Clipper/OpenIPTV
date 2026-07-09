import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Palette
  // ---------------------------------------------------------------------------

  static const _background = Color(0xFF0F0F0F);
  static const _surface = Color(0xFF1C1C1E);
  static const _surfaceVariant = Color(0xFF2C2C2E);
  static const _outline = Color(0xFF3A3A3C);
  static const _defaultAccent = Color(0xFF0A84FF);
  static const _onPrimary = Colors.white;
  static const _onBackground = Color(0xFFF2F2F7);
  static const _onSurface = Color(0xFFEBEBF5);
  static const _onSurfaceVariant = Color(0xFF8E8E93);
  static const _error = Color(0xFFFF453A);

  // Available accent color swatches
  static const List<({String label, Color color})> accentSwatches = [
    (label: 'Blue', color: Color(0xFF0A84FF)),
    (label: 'Purple', color: Color(0xFFBF5AF2)),
    (label: 'Pink', color: Color(0xFFFF2D55)),
    (label: 'Orange', color: Color(0xFFFF9F0A)),
    (label: 'Green', color: Color(0xFF30D158)),
    (label: 'Teal', color: Color(0xFF5AC8FA)),
  ];

  // Public accessors so one-off screens (e.g. the setup wizard, which draws
  // its own gradient background before the app's theme is fully "committed")
  // can match the real palette instead of re-declaring their own hex values.
  static const backgroundColor = _background;
  static const surfaceColor = _surface;
  static const surfaceVariantColor = _surfaceVariant;
  static const outlineColor = _outline;
  static const mutedTextColor = _onSurfaceVariant;

  static Color accentFromHex(String hex) {
    try {
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return _defaultAccent;
    }
  }

  static String hexFromAccent(Color c) =>
      c.toARGB32().toRadixString(16).toUpperCase().substring(2);

  // ---------------------------------------------------------------------------
  // Dark theme (the app's only theme — see AppTheme.dark() usage in app.dart)
  // ---------------------------------------------------------------------------

  static ThemeData dark([Color? accent]) {
    final primary = accent ?? _defaultAccent;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _background,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: _onPrimary,
        secondary: primary,
        onSecondary: _onPrimary,
        surface: _surface,
        onSurface: _onSurface,
        surfaceContainerHighest: _surfaceVariant,
        onSurfaceVariant: _onSurfaceVariant,
        outline: _outline,
        outlineVariant: _surfaceVariant,
        inverseSurface: _onBackground,
        onInverseSurface: _background,
        surfaceTint: Colors.transparent,
        error: _error,
        onError: _onPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        foregroundColor: _onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _surface,
        selectedItemColor: primary,
        unselectedItemColor: _onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceVariant,
        selectedColor: primary.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: _onSurface, fontSize: 13),
        side: const BorderSide(color: Colors.transparent),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: const TextStyle(color: _onSurfaceVariant),
      ),
      textTheme: TextTheme(
        headlineLarge: const TextStyle(
            color: _onBackground, fontSize: 28, fontWeight: FontWeight.bold),
        headlineMedium: const TextStyle(
            color: _onBackground, fontSize: 22, fontWeight: FontWeight.w600),
        titleLarge: const TextStyle(
            color: _onBackground, fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: const TextStyle(
            color: _onBackground, fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: const TextStyle(color: _onSurface, fontSize: 16),
        bodyMedium: const TextStyle(color: _onSurface, fontSize: 14),
        bodySmall: const TextStyle(color: _onSurfaceVariant, fontSize: 12),
        labelLarge: TextStyle(
            color: primary, fontSize: 14, fontWeight: FontWeight.w600),
      ),
      dividerTheme: const DividerThemeData(
        color: _surfaceVariant,
        thickness: 0.5,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _onSurfaceVariant,
        textColor: _onSurface,
        tileColor: Colors.transparent,
      ),
      iconTheme: const IconThemeData(color: _onSurfaceVariant),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: _onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _onSurface,
          side: const BorderSide(color: _outline),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
        titleTextStyle: const TextStyle(
            color: _onBackground, fontSize: 18, fontWeight: FontWeight.w600),
        contentTextStyle: const TextStyle(color: _onSurface, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceVariant,
        contentTextStyle: const TextStyle(color: _onSurface),
        actionTextColor: primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared constants
  // ---------------------------------------------------------------------------

  static const posterAspectRatio = 2 / 3;
  static const cardRadius = 12.0;

  static BoxDecoration focusDecoration(Color accent) => BoxDecoration(
        border: Border.all(color: accent, width: 3),
        borderRadius: BorderRadius.circular(cardRadius),
      );

  /// Style for a destructive/irreversible confirm action in a dialog
  /// (Delete, Remove) — a solid error-colored FilledButton, applied
  /// consistently everywhere a destructive confirm button appears.
  static ButtonStyle destructiveButtonStyle(BuildContext context) =>
      FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.error,
        foregroundColor: Theme.of(context).colorScheme.onError,
      );
}
