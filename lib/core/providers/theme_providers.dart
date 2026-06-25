import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';

// Session-level providers — initialized in app.dart after prefs load.
// Use notifier.state = x to update; app reads reactively via ref.watch.

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

final accentColorProvider =
    StateProvider<Color>((ref) => AppTheme.accentFromHex('0A84FF'));

final contentSortProvider = StateProvider<String>((ref) => 'provider');

// Helpers called from Settings to update prefs + provider in one shot.
Future<void> setThemeMode(
    WidgetRef ref, ThemeMode mode, AppPreferences prefs) async {
  ref.read(themeModeProvider.notifier).state = mode;
  await prefs.setThemeMode(_modeToString(mode));
}

Future<void> setAccentColor(
    WidgetRef ref, Color color, AppPreferences prefs) async {
  ref.read(accentColorProvider.notifier).state = color;
  await prefs.setAccentColor(AppTheme.hexFromAccent(color));
}

Future<void> setContentSort(
    WidgetRef ref, String sort, AppPreferences prefs) async {
  ref.read(contentSortProvider.notifier).state = sort;
  await prefs.setContentSort(sort);
}

String _modeToString(ThemeMode m) => switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
      _ => 'dark',
    };

ThemeMode modeFromString(String s) => switch (s) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
