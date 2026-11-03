// Anonymous crash reports (#150): the one entry point. Read
// docs/design/anonymous-stats.md for the promise this code keeps.
//
//  * Nothing is recorded, queued or sent unless the saved choice is 'on'.
//  * Every call is wrapped so telemetry itself can never crash the app or
//    slow down startup or playback.
//  * Only what report.dart defines is ever stored or sent.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_iptv/telemetry/consent.dart';
import 'package:open_iptv/telemetry/queue.dart';
import 'package:open_iptv/telemetry/report.dart';
import 'package:open_iptv/telemetry/sender.dart';
import 'package:open_iptv/ui/platform_helper.dart';

const _device = MethodChannel('openiptv/device');
const _lastSendKey = 'stats_last_send_ms';
const _sendEvery = Duration(days: 1);
// A crash loop must not flood the queue.
const _maxPerRun = 5;

class Telemetry {
  Telemetry._();

  static int _recorded = 0;
  static bool _busy = false;
  static DeviceFacts? _facts;

  /// Hooks Dart's uncaught-error handlers. Existing handlers still run.
  static void install() {
    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      unawaited(_record(details.exception, details.stack ?? StackTrace.empty,
          ReportKind.crash));
      previousFlutter?.call(details);
    };
    final previousPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(_record(error, stack, ReportKind.crash));
      return previousPlatform?.call(error, stack) ?? false;
    };
  }

  /// Run a moment after launch (never before the first frame): picks up a
  /// native crash from last time and sends what is waiting, at most daily.
  static Future<void> startup() async {
    try {
      if (await readStatsChoice() != StatsChoice.on) {
        await _discardNativeCrash();
        return;
      }
      await _ingestNativeCrash();
      await _flushIfDue();
    } catch (e) {
      debugPrint('[OTV-stats] startup skipped: $e');
    }
  }

  /// Saves the user's choice. Turning it off also deletes what is queued.
  static Future<void> setChoice(StatsChoice choice) async {
    await writeStatsChoice(choice);
    if (choice != StatsChoice.on) {
      await (await _queue()).clear();
      await _discardNativeCrash();
    }
  }

  /// The queued reports, exactly as they would be sent.
  static Future<List<Map<String, dynamic>>> queued() async =>
      (await _queue()).read();

  static Future<void> clearQueued() async => (await _queue()).clear();

  static Future<ReportQueue> _queue() async {
    final dir = await getApplicationSupportDirectory();
    return ReportQueue(File('${dir.path}/telemetry/queue.json'));
  }

  static Future<DeviceFacts> _deviceFacts() async {
    final cached = _facts;
    if (cached != null) return cached;
    final info = await PackageInfo.fromPlatform();
    Map<dynamic, dynamic> native = const {};
    try {
      native = await _device.invokeMapMethod<dynamic, dynamic>('deviceFacts') ??
          const {};
    } catch (_) {}
    return _facts = DeviceFacts(
      app: '${info.version}+${info.buildNumber}',
      platform: PlatformHelper.isTVDevice ? 'android-tv' : 'android',
      os: (native['sdk'] as num?)?.toInt() ?? 0,
      device: '${native['manufacturer'] ?? ''} ${native['model'] ?? ''}'.trim(),
    );
  }

  static Future<void> _record(
      Object error, StackTrace stack, ReportKind kind) async {
    if (_busy || _recorded >= _maxPerRun) return;
    _busy = true;
    try {
      if (await readStatsChoice() != StatsChoice.on) return;
      final report = StatsReport.build(
        facts: await _deviceFacts(),
        now: DateTime.now(),
        kind: kind,
        errorType: error.runtimeType.toString(),
        rawStack: stack.toString(),
      );
      await (await _queue()).add(report.toJson());
      _recorded++;
    } catch (_) {
      // Never let reporting cause a problem of its own.
    } finally {
      _busy = false;
    }
  }

  /// The native crash handler (OpenIptvApplication) saves the crash to a file
  /// only while the choice is 'on'; it is turned into a report here.
  static Future<void> _ingestNativeCrash() async {
    final crash = await _device
        .invokeMapMethod<String, String>('takeNativeCrash')
        .catchError((_) => null);
    if (crash == null) return;
    final report = StatsReport.build(
      facts: await _deviceFacts(),
      now: DateTime.now(),
      kind: ReportKind.nativeCrash,
      errorType: crash['type'] ?? '',
      rawStack: crash['stack'] ?? '',
    );
    await (await _queue()).add(report.toJson());
  }

  static Future<void> _discardNativeCrash() async {
    try {
      await _device.invokeMethod('takeNativeCrash');
    } catch (_) {}
  }

  static Future<void> _flushIfDue() async {
    if (!statsEndpointConfigured) return;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastSendKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < _sendEvery.inMilliseconds) return;
    final queue = await _queue();
    final waiting = await queue.read();
    if (waiting.isEmpty) return;
    final failed = await sendReports(waiting);
    await queue.replace(failed);
    // Only count a day as "sent" when something got through.
    if (failed.length < waiting.length) await prefs.setInt(_lastSendKey, now);
  }
}
