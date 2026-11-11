import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/device_info_channel.dart';
import 'package:open_iptv/core/services/image_quality.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/auto_refresh_service.dart';
import 'package:open_iptv/core/services/now_playing_service.dart';
import 'package:open_iptv/core/services/native_video_player.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/ui/platform_helper.dart';

// Session-level providers — initialized in app.dart after prefs load.
// Use notifier.state = x to update; app reads reactively via ref.watch.

final accentColorProvider =
    StateProvider<Color>((ref) => AppTheme.defaultAccent);

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

// Picture-in-Picture — runtime cache of the preference. Default matches
// the persisted default (on for phones/tablets, off on TV).
final pipEnabledProvider =
    StateProvider<bool>((ref) => !PlatformHelper.isTVDevice);
// Auto frame rate (#149) — runtime cache of the preference.
final autoFrameRateProvider = StateProvider<bool>((ref) => false);
// Bumped when Home is pressed and Picture-in-Picture isn't going to take
// over: whatever is playing (player, guide preview, multi-view) stops.
final homeLeaveProvider = StateProvider<int>((ref) => 0);
final pipActiveProvider = StateProvider<bool>((ref) => false);

// Whether the player screen has a transient overlay (channel switcher,
// etc.) open. PiP is suppressed while this is true so Home doesn't
// shrink a non-fullscreen overlay into the PiP window.
final playerOverlayOpenProvider = StateProvider<bool>((ref) => false);

// Now Playing / media notification.
final mediaNotificationEnabledProvider = StateProvider<bool>((ref) => true);

// Tidy provider names for display (see display_name.dart).
final cleanNamesProvider = StateProvider<bool>((ref) => true);

/// Power User Tools → Full-resolution pictures.
final fullResImagesProvider = StateProvider<bool>((ref) => true);

/// Player picture fit: 'fit' (whole picture, letterboxed — the default),
/// 'fill' (crop to fill the screen) or 'zoom' (in between).
final videoFitProvider = StateProvider<String>((ref) => 'fit');

Future<void> setVideoFit(
    WidgetRef ref, String fit, AppPreferences prefs) async {
  ref.read(videoFitProvider.notifier).state = fit;
  await prefs.setVideoFit(fit);
}

/// Keep the time of day on screen while watching full screen, even when the
/// controls are hidden (#56).
final playerClockAlwaysProvider = StateProvider<bool>((ref) => false);

Future<void> setPlayerClockAlways(
    WidgetRef ref, bool on, AppPreferences prefs) async {
  ref.read(playerClockAlwaysProvider.notifier).state = on;
  await prefs.setPlayerClockAlways(on);
}

/// Ask "Start from the beginning or Watch live?" on catch-up channels.
final askStartOverProvider = StateProvider<bool>((ref) => true);

Future<void> setAskStartOver(
    WidgetRef ref, bool on, AppPreferences prefs) async {
  ref.read(askStartOverProvider.notifier).state = on;
  await prefs.setAskStartOver(on);
}

/// Seconds the player's controls stay up (3, 4, 6, 8 or 12).
final panelTimeoutProvider = StateProvider<int>((ref) => 4);

Future<void> setPanelTimeout(
    WidgetRef ref, int seconds, AppPreferences prefs) async {
  ref.read(panelTimeoutProvider.notifier).state = seconds;
  await prefs.setPanelTimeoutSeconds(seconds);
}

/// Size of the player's skip back / forward jump in seconds (5, 10 or 30).
final skipSecondsProvider = StateProvider<int>((ref) => 10);

Future<void> setSkipSeconds(
    WidgetRef ref, int seconds, AppPreferences prefs) async {
  ref.read(skipSecondsProvider.notifier).state = seconds;
  await prefs.setSkipSeconds(seconds);
}

/// Remote keys that seek in catch-up and movies while the controls are
/// hidden: 'media' (rewind / fast-forward keys only), 'leftRight', 'upDown'.
final seekKeysProvider = StateProvider<String>((ref) => 'media');

Future<void> setSeekKeys(WidgetRef ref, String v, AppPreferences prefs) async {
  ref.read(seekKeysProvider.notifier).state = v;
  await prefs.setSeekKeys(v);
}

/// Lip-sync shift in milliseconds: positive plays the sound later.
final audioDelayProvider = StateProvider<int>((ref) => 0);

Future<void> setAudioDelay(WidgetRef ref, int ms, AppPreferences prefs) async {
  ref.read(audioDelayProvider.notifier).state = ms;
  await prefs.setAudioDelayMs(ms);
  await ref.read(playbackServiceProvider).setAudioDelay(ms);
}

/// Show resolution, frame rate and audio format next to the quality chip.
final streamDetailsProvider = StateProvider<bool>((ref) => true);

Future<void> setStreamDetails(
    WidgetRef ref, bool on, AppPreferences prefs) async {
  ref.read(streamDetailsProvider.notifier).state = on;
  await prefs.setStreamDetails(on);
}

/// Live TV categories (Favorites, Recently Watched, All Channels) and the TV
/// guide's display options, all switchable in Settings → Live TV.
final showFavoritesCategoryProvider = StateProvider<bool>((ref) => true);
final showRecentCategoryProvider = StateProvider<bool>((ref) => true);
final showAllCategoryProvider = StateProvider<bool>((ref) => true);
final guideShowNamesProvider = StateProvider<bool>((ref) => true);
final guideTwoLineNamesProvider = StateProvider<bool>((ref) => true);
final guideTwoLineTitlesProvider = StateProvider<bool>((ref) => false);
final guideHighlightPlayingProvider = StateProvider<bool>((ref) => true);

/// Saves a Live TV option: sets [provider] and runs [save].
Future<void> setLiveOption(WidgetRef ref, StateProvider<bool> provider,
    bool v, Future<void> Function(bool) save) async {
  ref.read(provider.notifier).state = v;
  await save(v);
}

/// TV: open the app when the TV starts / wakes from sleep.
final startOnBootProvider = StateProvider<bool>((ref) => false);
final startOnWakeProvider = StateProvider<bool>((ref) => false);

Future<void> setStartup(WidgetRef ref, AppPreferences prefs,
    {bool? boot, bool? wake}) async {
  if (boot != null) {
    ref.read(startOnBootProvider.notifier).state = boot;
    await prefs.setStartOnBoot(boot);
  }
  if (wake != null) {
    ref.read(startOnWakeProvider.notifier).state = wake;
    await prefs.setStartOnWake(wake);
  }
  await setStartupOptions(boot: prefs.startOnBoot, wake: prefs.startOnWake);
}

/// Text size multiplier, on top of the system's (0.85, 1.0, 1.15, 1.3).
final fontScaleProvider = StateProvider<double>((ref) => 1.0);

Future<void> setFontScale(WidgetRef ref, double v, AppPreferences prefs) async {
  ref.read(fontScaleProvider.notifier).state = v;
  await prefs.setFontScale(v);
}

/// How see-through the player's panels and controls backdrop are:
/// 'solid' | 'normal' | 'clear' | 'veryclear'.
final overlayOpacityProvider = StateProvider<String>((ref) => 'normal');

Future<void> setOverlayOpacity(
    WidgetRef ref, String v, AppPreferences prefs) async {
  ref.read(overlayOpacityProvider.notifier).state = v;
  await prefs.setOverlayOpacity(v);
}

/// The alpha to draw an overlay with, given its normal [base] alpha.
double overlayAlpha(String mode, double base) => switch (mode) {
      'solid' => 1.0,
      'clear' => base * 0.75,
      'veryclear' => base * 0.55,
      _ => base,
    };

/// The same for a dark backdrop behind text, which gets stronger (not
/// just opaque) when [mode] is solid, so the text stays readable.
double scrimAlpha(String mode, double base) => switch (mode) {
      'solid' => (base * 1.4).clamp(0.0, 1.0),
      'clear' => base * 0.7,
      'veryclear' => base * 0.45,
      _ => base,
    };

/// Open the last watched channel when the app starts.
final lastChannelOnStartProvider = StateProvider<bool>((ref) => false);

Future<void> setLastChannelOnStart(
    WidgetRef ref, bool on, AppPreferences prefs) async {
  ref.read(lastChannelOnStartProvider.notifier).state = on;
  await prefs.setLastChannelOnStart(on);
}

// Movies / Series home layout: 'posters' (a rail per genre) or 'compact'
// (the plain genre list).
final homeLayoutMoviesProvider = StateProvider<String>((ref) => 'posters');
final homeLayoutSeriesProvider = StateProvider<String>((ref) => 'posters');

Future<void> setHomeLayoutMovies(
    WidgetRef ref, String layout, AppPreferences prefs) async {
  ref.read(homeLayoutMoviesProvider.notifier).state = layout;
  await prefs.setHomeLayoutMovies(layout);
}

Future<void> setHomeLayoutSeries(
    WidgetRef ref, String layout, AppPreferences prefs) async {
  ref.read(homeLayoutSeriesProvider.notifier).state = layout;
  await prefs.setHomeLayoutSeries(layout);
}

Future<void> setFullResImages(
    WidgetRef ref, bool enabled, AppPreferences prefs) async {
  ref.read(fullResImagesProvider.notifier).state = enabled;
  ImageQuality.applyCacheBudget(enabled);
  await prefs.setFullResImages(enabled);
}

Future<void> setCleanNames(
    WidgetRef ref, bool enabled, AppPreferences prefs) async {
  ref.read(cleanNamesProvider.notifier).state = enabled;
  await prefs.setCleanNames(enabled);
}

// Helpers called from Settings to update prefs + provider in one shot.
Future<void> setAccentColor(
    WidgetRef ref, Color color, AppPreferences prefs) async {
  ref.read(accentColorProvider.notifier).state = color;
  await prefs.setAccentColor(AppTheme.hexFromAccent(color));
  // Also persist on the active profile so the color is profile-specific.
  final profile = ref.read(activeProfileProvider).valueOrNull;
  if (profile != null) {
    final db = ref.read(appDatabaseProvider);
    await db.upsertProfile(profile.copyWith(accentColor: AppTheme.hexFromAccent(color)));
  }
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
  debugPrint('[OTV-source] set active=$id');
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

Future<void> setAutoFrameRate(
    WidgetRef ref, bool enabled, AppPreferences prefs) async {
  ref.read(autoFrameRateProvider.notifier).state = enabled;
  await prefs.setAutoFrameRate(enabled);
  await NativeVideoPlayer.setAutoFrameRate(enabled);
}

Future<void> setPipEnabled(
    WidgetRef ref, bool enabled, AppPreferences prefs) async {
  ref.read(pipEnabledProvider.notifier).state = enabled;
  await prefs.setPipEnabled(enabled);
  // PiP availability is recomputed by the listener in app.dart whenever
  // pipEnabledProvider changes — that's where PlayerScreen.openCount is
  // checked, so Home can't shrink a non-player screen into a smooshed window.
}

Future<void> setMediaNotificationEnabled(
    WidgetRef ref, bool enabled, AppPreferences prefs) async {
  ref.read(mediaNotificationEnabledProvider.notifier).state = enabled;
  await prefs.setMediaNotificationEnabled(enabled);
  nowPlayingHandler.setEnabled(enabled);
}

/// Pushes every persisted setting into its runtime StateProvider. These
/// providers are plain state (not derived from [AppPreferences] reactively),
/// so anything that writes prefs out-of-band — app startup, or restoring a
/// backup — must call this afterward or the UI keeps showing stale values
/// until the app restarts.
void syncSettingsProviders(WidgetRef ref, AppPreferences prefs) {
  final activeProfile = ref.read(activeProfileProvider).valueOrNull;
  final accentHex = activeProfile?.accentColor ?? prefs.accentColor;
  ref.read(accentColorProvider.notifier).state =
      AppTheme.accentFromHex(accentHex);
  ref.read(contentSortProvider.notifier).state = prefs.contentSort;
  ref.read(viewModeLiveProvider.notifier).state = prefs.viewModeLive;
  ref.read(viewModeMoviesProvider.notifier).state = prefs.viewModeMovies;
  ref.read(viewModeSeriesProvider.notifier).state = prefs.viewModeSeries;
  ref.read(refreshIntervalHoursProvider.notifier).state =
      prefs.refreshIntervalHours;
  ref.read(refreshNotificationsEnabledProvider.notifier).state =
      prefs.refreshNotificationsEnabled;
  ref.read(pipEnabledProvider.notifier).state = prefs.pipEnabled;
  ref.read(autoFrameRateProvider.notifier).state = prefs.autoFrameRate;
  NativeVideoPlayer.setAutoFrameRate(prefs.autoFrameRate);
  NativeVideoPlayer.setOutputModes(
      passthrough: prefs.audioPassthrough, tunneling: prefs.tunneledPlayback);
  ref.read(mediaNotificationEnabledProvider.notifier).state =
      prefs.mediaNotificationEnabled;
  nowPlayingHandler.setEnabled(prefs.mediaNotificationEnabled);
  ref.read(cleanNamesProvider.notifier).state = prefs.cleanNames;
  ref.read(fullResImagesProvider.notifier).state = prefs.fullResImages;
  ImageQuality.applyCacheBudget(prefs.fullResImages);
  ref.read(videoFitProvider.notifier).state = prefs.videoFit;
  ref.read(playerClockAlwaysProvider.notifier).state = prefs.playerClockAlways;
  ref.read(askStartOverProvider.notifier).state = prefs.askStartOver;
  ref.read(panelTimeoutProvider.notifier).state = prefs.panelTimeoutSeconds;
  ref.read(skipSecondsProvider.notifier).state = prefs.skipSeconds;
  ref.read(streamDetailsProvider.notifier).state = prefs.streamDetails;
  ref.read(seekKeysProvider.notifier).state = prefs.seekKeys;
  ref.read(fontScaleProvider.notifier).state = prefs.fontScale;
  ref.read(showFavoritesCategoryProvider.notifier).state =
      prefs.showFavoritesCategory;
  ref.read(showRecentCategoryProvider.notifier).state = prefs.showRecentCategory;
  ref.read(showAllCategoryProvider.notifier).state = prefs.showAllCategory;
  ref.read(guideShowNamesProvider.notifier).state = prefs.guideShowNames;
  ref.read(guideTwoLineNamesProvider.notifier).state = prefs.guideTwoLineNames;
  ref.read(guideTwoLineTitlesProvider.notifier).state = prefs.guideTwoLineTitles;
  ref.read(guideHighlightPlayingProvider.notifier).state =
      prefs.guideHighlightPlaying;
  ref.read(startOnBootProvider.notifier).state = prefs.startOnBoot;
  ref.read(startOnWakeProvider.notifier).state = prefs.startOnWake;
  unawaited(setStartupOptions(boot: prefs.startOnBoot, wake: prefs.startOnWake));
  ref.read(overlayOpacityProvider.notifier).state = prefs.overlayOpacity;
  ref.read(audioDelayProvider.notifier).state = prefs.audioDelayMs;
  unawaited(ref
      .read(playbackServiceProvider)
      .setAudioDelay(prefs.audioDelayMs)
      .catchError((Object _) {}));
  ref.read(lastChannelOnStartProvider.notifier).state =
      prefs.lastChannelOnStart;
  ref.read(homeLayoutMoviesProvider.notifier).state = prefs.homeLayoutMovies;
  ref.read(homeLayoutSeriesProvider.notifier).state = prefs.homeLayoutSeries;
}
