import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Palette
  // ---------------------------------------------------------------------------

  static const _background = Color(0xFF0F0F0F);
  static const _surface = Color(0xFF1C1C1E);
  static const _surfaceVariant = Color(0xFF2C2C2E);
  static const _primary = Color(0xFF0A84FF);
  static const _onPrimary = Colors.white;
  static const _onBackground = Color(0xFFF2F2F7);
  static const _onSurface = Color(0xFFEBEBF5);
  static const _onSurfaceVariant = Color(0xFF8E8E93);
  static const _error = Color(0xFFFF453A);

  // TV-safe: keeps brightness between 15% and 85% to avoid blooming
  static const _tvBackground = Color(0xFF111111);

  // ---------------------------------------------------------------------------
  // Dark theme (default)
  // ---------------------------------------------------------------------------

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.dark(
          primary: _primary,
          onPrimary: _onPrimary,
          surface: _surface,
          onSurface: _onSurface,
          surfaceContainerHighest: _surfaceVariant,
          onSurfaceVariant: _onSurfaceVariant,
          error: _error,
          background: _background,
          onBackground: _onBackground,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: _onBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: _surface,
          selectedItemColor: _primary,
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
          selectedColor: _primary.withOpacity(0.2),
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
            borderSide: const BorderSide(color: _primary, width: 1.5),
          ),
          hintStyle: const TextStyle(color: _onSurfaceVariant),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
              color: _onBackground, fontSize: 28, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(
              color: _onBackground, fontSize: 22, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(
              color: _onBackground, fontSize: 18, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(
              color: _onBackground, fontSize: 16, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: _onSurface, fontSize: 16),
          bodyMedium: TextStyle(color: _onSurface, fontSize: 14),
          bodySmall: TextStyle(color: _onSurfaceVariant, fontSize: 12),
          labelLarge: TextStyle(
              color: _primary, fontSize: 14, fontWeight: FontWeight.w600),
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
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: _primary,
        ),
      );

  // ---------------------------------------------------------------------------
  // Light theme
  // ---------------------------------------------------------------------------

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
          brightness: Brightness.light,
        ),
      );

  // ---------------------------------------------------------------------------
  // TV theme (dark base, larger text, focus rings always visible)
  // ---------------------------------------------------------------------------

  static ThemeData get tv => dark.copyWith(
        scaffoldBackgroundColor: _tvBackground,
        colorScheme: dark.colorScheme.copyWith(
          background: _tvBackground,
        ),
        textTheme: dark.textTheme.copyWith(
          headlineLarge: dark.textTheme.headlineLarge!.copyWith(fontSize: 36),
          headlineMedium: dark.textTheme.headlineMedium!.copyWith(fontSize: 28),
          titleLarge: dark.textTheme.titleLarge!.copyWith(fontSize: 24),
          titleMedium: dark.textTheme.titleMedium!.copyWith(fontSize: 20),
          bodyLarge: dark.textTheme.bodyLarge!.copyWith(fontSize: 20),
          bodyMedium: dark.textTheme.bodyMedium!.copyWith(fontSize: 18),
        ),
      );

  // ---------------------------------------------------------------------------
  // Shared constants
  // ---------------------------------------------------------------------------

  static const posterAspectRatio = 2 / 3;
  static const cardRadius = 12.0;
  static const shimmerBase = Color(0xFF1C1C1E);
  static const shimmerHighlight = Color(0xFF2C2C2E);

  static BoxDecoration get focusDecoration => BoxDecoration(
        border: Border.all(color: _primary, width: 3),
        borderRadius: BorderRadius.circular(cardRadius),
      );
}
