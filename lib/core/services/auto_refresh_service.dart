import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const _kAutoRefreshUniqueName = 'openiptv_auto_refresh';
const _kAutoRefreshTaskName = 'autoRefresh';
const _kNotificationChannelId = 'playlist_refresh';
const _kNotificationChannelName = 'Playlist & EPG Refresh';
const _kNotificationChannelDescription =
    'Alerts when background playlist and TV guide updates succeed or fail';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

// ---------------------------------------------------------------------------
// App-side (main isolate) setup — call once at startup.
// ---------------------------------------------------------------------------

/// Initializes WorkManager and the local-notifications plugin. Call once
/// from `main()`, before any registration/cancellation calls.
Future<void> initAutoRefresh() async {
  await Workmanager().initialize(autoRefreshCallbackDispatcher);
  await _initNotifications();
}

Future<void> _initNotifications() async {
  const androidSettings =
      AndroidInitializationSettings('@drawable/ic_stat_open_iptv');
  const settings = InitializationSettings(android: androidSettings);
  await _notifications.initialize(settings);

  const channel = AndroidNotificationChannel(
    _kNotificationChannelId,
    _kNotificationChannelName,
    description: _kNotificationChannelDescription,
    importance: Importance.defaultImportance,
  );
  await _notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

/// Requests the Android 13+ runtime notification permission. Returns true if
/// granted (or not required on this OS version).
Future<bool> requestNotificationPermission() async {
  final granted = await _notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  return granted ?? true;
}

/// Registers, updates, or cancels the periodic background task so it matches
/// [AppPreferences.refreshIntervalHours]. Safe to call on every app startup
/// and whenever the user changes the interval in Settings — WorkManager has
/// no API to read back a task's currently-registered interval, so we track
/// what we last registered ourselves to decide whether re-registration is
/// actually needed.
Future<void> syncAutoRefreshRegistration(AppPreferences prefs) async {
  final desired = prefs.refreshIntervalHours;
  final lastRegistered = prefs.lastRegisteredRefreshIntervalHours;

  if (desired <= 0) {
    if (lastRegistered > 0) {
      await Workmanager().cancelByUniqueName(_kAutoRefreshUniqueName);
      await prefs.setLastRegisteredRefreshIntervalHours(0);
    }
    return;
  }

  if (desired == lastRegistered) return;

  await Workmanager().registerPeriodicTask(
    _kAutoRefreshUniqueName,
    _kAutoRefreshTaskName,
    frequency: Duration(hours: desired),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    constraints: Constraints(networkType: NetworkType.connected),
  );
  await prefs.setLastRegisteredRefreshIntervalHours(desired);
}

/// Requests exemption from Android's battery optimization for more reliable
/// background refresh timing. Not required for the feature to work — declines
/// or unsupported platforms just mean the OS may defer refreshes more
/// aggressively. Call only after showing an in-app rationale, and only when
/// the user is actively turning auto-refresh on.
Future<void> requestBatteryOptimizationExemption() async {
  final status = await Permission.ignoreBatteryOptimizations.status;
  if (!status.isGranted) {
    await Permission.ignoreBatteryOptimizations.request();
  }
}

// ---------------------------------------------------------------------------
// Background isolate — WorkManager callback dispatcher.
// ---------------------------------------------------------------------------

/// Entry point WorkManager invokes in a separate background isolate with no
/// access to the running app's Riverpod state — every dependency below is
/// constructed directly rather than read from a provider.
@pragma('vm:entry-point')
void autoRefreshCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    final db = AppDatabase();
    final epgService = EpgService(db: db);
    final sourceManager = SourceManager(db: db, epgService: epgService);
    final prefs = AppPreferences(await SharedPreferences.getInstance());

    final sources = await db.getAllSources();
    final results = <SourceRefreshResult>[];
    for (final source in sources) {
      results.add(await sourceManager.refreshSourceConcurrent(source));
    }

    if (prefs.refreshNotificationsEnabled) {
      await _initNotifications();
      await _showRefreshNotification(results);
    }

    return true;
  });
}

Future<void> _showRefreshNotification(List<SourceRefreshResult> results) async {
  if (results.isEmpty) return;

  final failed = results.where((r) => !r.succeeded).toList();
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      _kNotificationChannelId,
      _kNotificationChannelName,
      channelDescription: _kNotificationChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  if (failed.isEmpty) {
    await _notifications.show(
      0,
      'Playlists updated',
      results.length == 1
          ? '${results.first.nickname} refreshed successfully.'
          : 'All ${results.length} sources refreshed successfully.',
      details,
    );
    return;
  }

  final okCount = results.length - failed.length;
  final failedNames = failed.map((r) => r.nickname).join(', ');
  await _notifications.show(
    0,
    'Playlist refresh had problems',
    results.length == 1
        ? '${failed.first.nickname} failed to refresh — check the source in Settings.'
        : '$okCount of ${results.length} sources refreshed. Failed: $failedNames.',
    details,
  );
}
