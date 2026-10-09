import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/speed_test.dart';

void main() {
  late HttpServer server;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      switch (req.uri.path) {
        case '/file':
          // 4 MB, as fast as loopback goes.
          req.response.add(List.filled(4 * 1024 * 1024, 7));
        case '/live':
          // Endless, paced stream: 64 KB every 100 ms.
          for (var i = 0; i < 100; i++) {
            try {
              req.response.add(List.filled(64 * 1024, 1));
              await req.response.flush();
            } catch (_) {
              return;
            }
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        default:
          req.response.statusCode = 404;
      }
      await req.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  Uri url(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  test('a file is measured to the end', () async {
    final r = await measureDownload(url('/file'));
    expect(r.bytes, 4 * 1024 * 1024);
    expect(r.mbps, greaterThan(0));
    expect(r.paced, isFalse);
  });

  test('an endless live stream is cut off at the time limit', () async {
    final watch = Stopwatch()..start();
    final r = await measureDownload(url('/live'),
        maxDuration: const Duration(milliseconds: 700), paced: true);
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    expect(r.bytes, greaterThan(0));
    expect(r.paced, isTrue);
    // ~640 KB/s ≈ 5 Mbit/s; allow plenty of slack for a busy machine.
    expect(r.mbps, inInclusiveRange(1, 20));
  });

  test('an error response or nothing to download throws', () async {
    await expectLater(measureDownload(url('/missing')),
        throwsA(isA<SpeedTestException>()));
  });

  test('plain-English verdicts', () {
    SpeedResult at(double mbps) => SpeedResult(
        bytes: (mbps * 1000000 / 8).round(),
        elapsed: const Duration(seconds: 1),
        firstByte: Duration.zero);
    expect(at(30).verdict, contains('4K'));
    expect(at(12).verdict, contains('HD'));
    expect(at(1).verdict, contains('Too slow'));
  });
}
