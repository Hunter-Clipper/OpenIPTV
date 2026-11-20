import 'package:material_ui/material_ui.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/guide_assignment_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/db_encryption.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/sports/sports_reminders.dart';
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

const _kBgState = 'bg_refresh_state';
const _kBgStamp = 'bg_refresh_stamp';

/// What the background refresh is doing, as the app sees it.
enum BackgroundRefreshPhase { idle, running, done, problem }

/// A snapshot of the background refresh. [stamp] changes with every
/// change of [phase], so the app can tell a new run from one it already
/// announced.
class BackgroundRefreshStatus {
  const BackgroundRefreshStatus(this.phase, this.stamp);
  final BackgroundRefreshPhase phase;
  final int stamp;
}

/// The worker runs in its own isolate, so it can't show a toast itself: it
/// leaves its state in shared preferences and the open app reads it (see
/// [readBackgroundRefreshStatus]).
Future<void> _setBgState(SharedPreferences p, BackgroundRefreshPhase phase) async {
  await p.setString(_kBgState, phase.name);
  await p.setInt(_kBgStamp, DateTime.now().millisecondsSinceEpoch);
}

/// Reads the background refresh state written by the worker isolate.
/// A "running" mark older than 30 minutes is a worker that died: idle.
Future<BackgroundRefreshStatus> readBackgroundRefreshStatus() async {
  final p = await SharedPreferences.getInstance();
  await p.reload();
  final name = p.getString(_kBgState);
  final stamp = p.getInt(_kBgStamp) ?? 0;
  var phase = BackgroundRefreshPhase.values.firstWhere(
      (v) => v.name == name,
      orElse: () => BackgroundRefreshPhase.idle);
  if (phase == BackgroundRefreshPhase.running &&
      DateTime.now().millisecondsSinceEpoch - stamp > 30 * 60 * 1000) {
    phase = BackgroundRefreshPhase.idle;
  }
  return BackgroundRefreshStatus(phase, stamp);
}

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
  await _notifications.initialize(settings: settings);

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
    // First run one interval from now, not straight away: registration
    // happens right after a restore (or turning the setting on), when the
    // playlists have just been loaded — an immediate run downloaded every
    // playlist a second time, at the same time as the restore (#50).
    initialDelay: Duration(hours: desired),
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
    // The same dispatcher serves the Sports kickoff reminders.
    if (task == kSportsReminderTask) return runSportsReminderCheck();

    final db = AppDatabase.background();
    final epgService = EpgService(db: db);
    final sourceManager = SourceManager(db: db, epgService: epgService);
    final prefs = AppPreferences(await SharedPreferences.getInstance());

    final List<Source> sources;
    try {
      sources = await db.getAllSources();
    } on DatabaseNotReadyException {
      // The app hasn't encrypted an older database yet (it does on its
      // next launch). Skip this run rather than race it.
      await db.close();
      return true;
    } catch (e) {
      // Database or source loading failed — return false so WorkManager
      // retries the task.
      await db.close();
      return false;
    }
    final results = <SourceRefreshResult>[];
    final sp = await SharedPreferences.getInstance();
    if (sources.isNotEmpty) {
      await _setBgState(sp, BackgroundRefreshPhase.running);
    }
    try {
      for (final source in sources) {
        results.add(await sourceManager.refreshSourceConcurrent(source));
      }
    } catch (e) {
      // Unexpected error during refresh — close DB and return false for retry.
      await _setBgState(sp, BackgroundRefreshPhase.problem);
      await db.close();
      return false;
    }
    // Extra guides and smart links (never blocks or fails the refresh).
    try {
      await GuideAssignmentService(db: db).sync();
    } catch (_) {}

    if (results.isNotEmpty) {
      await _setBgState(
          sp,
          results.every((r) => r.succeeded)
              ? BackgroundRefreshPhase.done
              : BackgroundRefreshPhase.problem);
    }

    if (prefs.refreshNotificationsEnabled) {
      await _initNotifications();
      await _showRefreshNotification(results);
    }

    await db.close();
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
      id: 0,
      title: 'Playlists updated',
      body: results.length == 1
          ? '${results.first.nickname} refreshed.'
          : 'All ${results.length} playlists refreshed.',
      notificationDetails: details,
    );
    return;
  }

  final okCount = results.length - failed.length;
  final failedNames = failed.map((r) => r.nickname).join(', ');
  await _notifications.show(
    id: 0,
    title: 'Playlist refresh had problems',
    body: results.length == 1
        ? '${failed.first.nickname} failed to refresh — check the source in Settings.'
        : '$okCount of ${results.length} playlists refreshed. Failed: $failedNames.',
    notificationDetails: details,
  );
}
