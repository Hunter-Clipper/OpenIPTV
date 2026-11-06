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
// Waiting reports go out right away, but never more often than this, so a
// crash loop can't hammer the receiver.
const _minSendGap = Duration(minutes: 10);
// A crash loop must not flood the queue.
const _maxPerRun = 5;

class Telemetry {
  Telemetry._();

  static int _recorded = 0;
  static bool _busy = false;
  static bool _flushing = false;
  static DeviceFacts? _facts;

  /// Hooks Dart's uncaught-error handlers. Existing handlers still run.
  static void install() {
    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      // Silent errors are ones Flutter or a library already handled (a logo
      // that won't decode just shows the placeholder), so they aren't crashes.
      if (isReportableError(details.exception, silent: details.silent)) {
        unawaited(_record(details.exception,
            details.stack ?? StackTrace.empty, ReportKind.crash));
      }
      previousFlutter?.call(details);
    };
    final previousPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      if (isReportableError(error)) {
        unawaited(_record(error, stack, ReportKind.crash));
      }
      return previousPlatform?.call(error, stack) ?? false;
    };
  }

  /// Run a moment after launch (never before the first frame): picks up a
  /// native crash from last time and sends what is waiting, at most daily.
  static Future<void> startup() async {
    try {
      if (await readStatsChoice() != StatsChoice.on) {
        await _discardNativeCrash();
        await _discardExitInfo();
        return;
      }
      await _ingestNativeCrash();
      await _ingestExitInfo();
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
      await _discardExitInfo();
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

  /// Whether an uncaught error is a real crash worth reporting. Handled
  /// ("silent") framework errors and plain network failures (provider down,
  /// no signal) are not bugs in the app.
  @visibleForTesting
  static bool isReportableError(Object error, {bool silent = false}) {
    if (silent) return false;
    if (error is SocketException ||
        error is HandshakeException ||
        error is TimeoutException ||
        error is HttpException) {
      return false;
    }
    final type = error.runtimeType.toString();
    return !type.contains('SocketException') && !type.contains('ClientException');
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
      debugPrint('[OTV-stats] queued a ${kind.wire} report');
    } catch (_) {
      // Never let reporting cause a problem of its own.
    } finally {
      _busy = false;
    }
    // Send it now rather than waiting for the next launch (rate limited).
    unawaited(_flushIfDue());
  }

  /// Android keeps a short history of why the app's process ended. Freezes
  /// (ANRs) and native crashes never reach a Dart or Java error handler, so
  /// they are read from there on the next launch.
  static Future<void> _ingestExitInfo() async {
    final List<Map<dynamic, dynamic>> exits;
    try {
      final raw = await _device.invokeListMethod<Map<dynamic, dynamic>>(
              'takeExitReports', {'report': true}) ??
          const [];
      exits = raw;
    } catch (_) {
      return;
    }
    for (final e in exits) {
      final report = StatsReport.build(
        facts: await _deviceFacts(),
        now: DateTime.now(),
        kind: e['kind'] == 'hang' ? ReportKind.hang : ReportKind.nativeCrash,
        errorType: '${e['type'] ?? ''}',
        rawStack: '${e['stack'] ?? ''}',
      );
      await (await _queue()).add(report.toJson());
      debugPrint('[OTV-stats] queued a ${report.kind.wire} report (exit history)');
    }
  }

  /// Marks the exit history as seen without reporting it.
  static Future<void> _discardExitInfo() async {
    try {
      await _device.invokeMethod('takeExitReports');
    } catch (_) {}
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
    try {
      if (!statsEndpointConfigured || _flushing) return;
      if (await readStatsChoice() != StatsChoice.on) return;
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_lastSendKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < _minSendGap.inMilliseconds) {
        debugPrint('[OTV-stats] send held back (sent recently)');
        return;
      }
      final queue = await _queue();
      final waiting = await queue.read();
      if (waiting.isEmpty) return;
      _flushing = true;
      final failed = await sendReports(waiting);
      // Reports queued while sending must not be lost.
      final current = await queue.read();
      final added = current.length > waiting.length
          ? current.sublist(waiting.length)
          : const <Map<String, dynamic>>[];
      await queue.replace([...failed, ...added]);
      debugPrint('[OTV-stats] sent ${waiting.length - failed.length} of '
          '${waiting.length} report(s)');
      // Only count it as "sent" when something got through.
      if (failed.length < waiting.length) await prefs.setInt(_lastSendKey, now);
    } catch (e) {
      debugPrint('[OTV-stats] send skipped: $e');
    } finally {
      _flushing = false;
    }
  }
}
