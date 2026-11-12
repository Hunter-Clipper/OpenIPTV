import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:open_iptv/l10n/gen/app_localizations.dart';

/// Result of one download measurement.
class SpeedResult {
  const SpeedResult({
    required this.bytes,
    required this.elapsed,
    required this.firstByte,
    this.paced = false,
  });

  final int bytes;
  final Duration elapsed;

  /// Time until the server started sending — a feel for latency.
  final Duration firstByte;

  /// Measured on a live stream, which the server sends at playback speed:
  /// the number shows whether the connection keeps up, not its maximum.
  final bool paced;

  double get mbps => elapsed.inMicroseconds <= 0
      ? 0
      : bytes * 8 / elapsed.inMicroseconds; // bits per µs == Mbit/s

  /// Plain-English verdict for an IPTV viewer.
  String verdict(AppLocalizations l10n) {
    final m = mbps;
    if (m >= 25) return l10n.speedTestVerdictPlenty;
    if (m >= 10) return l10n.speedTestVerdictGood;
    if (m >= 5) return l10n.speedTestVerdictFineHd;
    if (m >= 2.5) return l10n.speedTestVerdictEnoughSd;
    return l10n.speedTestVerdictTooSlow;
  }
}

/// Why a speed test couldn't run.
class SpeedTestException implements Exception {
  const SpeedTestException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Downloads [url] for up to [maxDuration] (or [maxBytes]) and measures the
/// speed. The data is thrown away. [onProgress] gets the running Mbit/s.
Future<SpeedResult> measureDownload(
  Uri url, {
  http.Client? client,
  Duration maxDuration = const Duration(seconds: 8),
  int maxBytes = 200 * 1024 * 1024,
  Duration connectTimeout = const Duration(seconds: 10),
  bool paced = false,
  void Function(double mbps)? onProgress,
}) async {
  final c = client ?? http.Client();
  final watch = Stopwatch()..start();
  StreamSubscription<List<int>>? sub;
  try {
    final res = await c
        .send(http.Request('GET', url))
        .timeout(connectTimeout);
    if (res.statusCode >= 400) {
      throw SpeedTestException('http_${res.statusCode}');
    }
    final firstByte = watch.elapsed;
    final started = Stopwatch()..start();
    var bytes = 0;
    final done = Completer<void>();
    sub = res.stream.listen(
      (chunk) {
        bytes += chunk.length;
        onProgress?.call(bytes * 8 / started.elapsedMicroseconds.clamp(1, 1 << 62));
        if (bytes >= maxBytes && !done.isCompleted) done.complete();
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      onError: (Object e) {
        if (!done.isCompleted) done.completeError(e);
      },
      cancelOnError: true,
    );
    await done.future.timeout(maxDuration, onTimeout: () {});
    final elapsed = started.elapsed;
    if (bytes == 0) throw const SpeedTestException('no_data');
    return SpeedResult(
        bytes: bytes, elapsed: elapsed, firstByte: firstByte, paced: paced);
  } on TimeoutException {
    throw const SpeedTestException('timeout');
  } finally {
    await sub?.cancel();
    if (client == null) c.close();
  }
}

/// The public file used for the optional general internet test — named in
/// the app, since it's a third party (only contacted when tapped).
const kInternetSpeedHost = 'speed.cloudflare.com';
Uri internetSpeedUrl() =>
    // 25 MB: the service refuses larger single downloads (403).
    Uri.https(kInternetSpeedHost, '/__down', {'bytes': '25000000'});
