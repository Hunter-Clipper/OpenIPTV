// The anonymous report (#150). This file is the ONLY place that defines what
// leaves the device: every field below is listed in docs/design/anonymous-stats.md
// and shown to the user in Settings → Advanced → Anonymous Reports.
//
// Deliberately absent: exception messages, URLs, host names, IPs, logins,
// playlist / profile / channel / title names, search text, settings, and any
// device or install ID.

import 'package:open_iptv/telemetry/scrubber.dart';

/// What kind of failure this is. Crashes and fatal errors only.
enum ReportKind {
  /// An uncaught error in the app's Dart code.
  crash('crash'),

  /// An uncaught crash in the native (Kotlin/Java) layer.
  nativeCrash('native-crash');

  const ReportKind(this.wire);
  final String wire;
}

/// Device facts a report may carry (no IDs).
class DeviceFacts {
  const DeviceFacts({
    required this.app,
    required this.platform,
    required this.os,
    required this.device,
  });

  /// `0.14.51+17`
  final String app;

  /// `android` or `android-tv`.
  final String platform;

  /// Android API level, e.g. 34.
  final int os;

  /// Maker and model, e.g. `Google Chromecast`.
  final String device;
}

class StatsReport {
  const StatsReport._({
    required this.facts,
    required this.day,
    required this.kind,
    required this.error,
    required this.stack,
  });

  /// Builds a report from raw crash material. Everything free-form goes
  /// through the scrubber here, so nothing unchecked can be stored or sent.
  factory StatsReport.build({
    required DeviceFacts facts,
    required DateTime now,
    required ReportKind kind,
    required String errorType,
    required String rawStack,
  }) {
    final utc = now.toUtc();
    final day = '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
    return StatsReport._(
      facts: DeviceFacts(
        app: scrubShortText(facts.app),
        platform: facts.platform == 'android-tv' ? 'android-tv' : 'android',
        os: facts.os,
        device: scrubShortText(facts.device),
      ),
      day: day,
      kind: kind,
      error: scrubErrorType(errorType),
      stack: scrubStack(rawStack),
    );
  }

  /// Payload version.
  static const version = 1;

  final DeviceFacts facts;

  /// The date only (UTC), never a time.
  final String day;
  final ReportKind kind;

  /// Exception class name only — never its message.
  final String error;

  /// Up to 30 scrubbed code lines.
  final List<String> stack;

  Map<String, Object> toJson() => {
        'v': version,
        'app': facts.app,
        'platform': facts.platform,
        'os': facts.os,
        'device': facts.device,
        'day': day,
        'kind': kind.wire,
        'error': error,
        'stack': stack,
      };
}
