import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/auto_refresh_service.dart';
import 'package:open_iptv/core/services/now_playing_service.dart';
import 'package:open_iptv/core/services/pip_service.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';

// Session-level providers — initialized in app.dart after prefs load.
// Use notifier.state = x to update; app reads reactively via ref.watch.

final accentColorProvider =
    StateProvider<Color>((ref) => AppTheme.accentFromHex('0A84FF'));

final contentSortProvider = StateProvider<String>((ref) => 'provider');

// View mode per content type — defaults match Option C smart defaults.
final viewModeLiveProvider = StateProvider<String>((ref) => 'list');
final viewModeMoviesProvider = StateProvider<String>((ref) => 'grid');
final viewModeSeriesProvider = StateProvider<String>((ref) => 'grid');

// Active source — null means show all sources' content combined.
// Initialized from prefs in app.dart after DB is ready.
final activeSourceIdProvider = StateProvider<String?>((ref) => null);

// Background auto-refresh — 0 means off.
final refreshIntervalHoursProvider = StateProvider<int>((ref) => 0);
final refreshNotificationsEnabledProvider = StateProvider<bool>((ref) => true);

// Picture-in-Picture — pipActiveProvider is runtime-only (not persisted),
// updated live by MainActivity via the platform channel in pip_service.dart.
final pipEnabledProvider = StateProvider<bool>((ref) => true);
final pipActiveProvider = StateProvider<bool>((ref) => false);

// Now Playing / media notification.
final mediaNotificationEnabledProvider = StateProvider<bool>((ref) => true);

// Helpers called from Settings to update prefs + provider in one shot.
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

Future<void> setViewModeLive(
    WidgetRef ref, String mode, AppPreferences prefs) async {
  ref.read(viewModeLiveProvider.notifier).state = mode;
  await prefs.setViewModeLive(mode);
}

Future<void> setViewModeMovies(
    WidgetRef ref, String mode, AppPreferences prefs) async {
  ref.read(viewModeMoviesProvider.notifier).state = mode;
  await prefs.setViewModeMovies(mode);
}

Future<void> setViewModeSeries(
    WidgetRef ref, String mode, AppPreferences prefs) async {
  ref.read(viewModeSeriesProvider.notifier).state = mode;
  await prefs.setViewModeSeries(mode);
}

Future<void> setActiveSource(
    WidgetRef ref, String? id, AppPreferences prefs) async {
  ref.read(activeSourceIdProvider.notifier).state = id;
  await prefs.setActiveSourceId(id);
}

Future<void> setRefreshIntervalHours(
    WidgetRef ref, int hours, AppPreferences prefs) async {
  ref.read(refreshIntervalHoursProvider.notifier).state = hours;
  await prefs.setRefreshIntervalHours(hours);
  await syncAutoRefreshRegistration(prefs);
}

Future<void> setRefreshNotificationsEnabled(
    WidgetRef ref, bool enabled, AppPreferences prefs) async {
  ref.read(refreshNotificationsEnabledProvider.notifier).state = enabled;
  await prefs.setRefreshNotificationsEnabled(enabled);
}

Future<void> setPipEnabled(
    WidgetRef ref, bool enabled, AppPreferences prefs) async {
  ref.read(pipEnabledProvider.notifier).state = enabled;
  await prefs.setPipEnabled(enabled);
  final playing = ref.read(playbackServiceProvider).player.state.playing;
  await updatePipAvailability(enabled && playing);
}

Future<void> setMediaNotificationEnabled(
    WidgetRef ref, bool enabled, AppPreferences prefs) async {
  ref.read(mediaNotificationEnabledProvider.notifier).state = enabled;
  await prefs.setMediaNotificationEnabled(enabled);
  nowPlayingHandler.setEnabled(enabled);
}
