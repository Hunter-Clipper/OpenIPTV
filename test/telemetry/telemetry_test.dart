import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_iptv/telemetry/consent.dart';
import 'package:open_iptv/telemetry/queue.dart';
import 'package:open_iptv/telemetry/report.dart';
import 'package:open_iptv/telemetry/scrubber.dart';
import 'package:open_iptv/telemetry/sender.dart';
import 'package:open_iptv/telemetry/telemetry.dart';

const _facts = DeviceFacts(
    app: '0.14.51+17', platform: 'android-tv', os: 34, device: 'Google Chromecast');

void main() {
  group('isReportableError', () {
    test('real crashes are reported', () {
      expect(Telemetry.isReportableError(StateError('x')), isTrue);
    });
    test('handled (silent) errors and network failures are not', () {
      expect(Telemetry.isReportableError(Exception('x'), silent: true), isFalse);
      expect(Telemetry.isReportableError(const SocketException('x')), isFalse);
      expect(Telemetry.isReportableError(http.ClientException('x')), isFalse);
    });
  });
  group('scrubber', () {
    test('keeps code frames, drops everything else', () {
      const raw = '''
#0      Foo.bar (package:open_iptv/features/x.dart:12:5)
#1      _rootRun (dart:async/zone.dart:1399:13)
#2      main (file:///home/hunter/Projects/IPTVClient/lib/main.dart:3:1)
#3      load (http://user:pass@10.0.1.52:8080/live/a/b/1.ts)
at com.openiptv.app.NativeVideoPlayer.open(NativeVideoPlayer.kt:10)
at androidx.media3.exoplayer.ExoPlayerImpl.prepare(ExoPlayerImpl.java:5)
mail me hunter@example.com package:foo
some random line about Channel BBC One
''';
      final out = scrubStack(raw);
      expect(out, [
        '#0      Foo.bar (package:open_iptv/features/x.dart:12:5)'.trim(),
        '#1      _rootRun (dart:async/zone.dart:1399:13)'.trim(),
        'at com.openiptv.app.NativeVideoPlayer.open(NativeVideoPlayer.kt:10)',
        'at androidx.media3.exoplayer.ExoPlayerImpl.prepare(ExoPlayerImpl.java:5)',
      ]);
    });

    test('drops a code line that carries an address', () {
      expect(scrubStack('x (package:a/b.dart:1) 192.168.1.20'), isEmpty);
      expect(scrubStack('x (package:a/b.dart:1) fe80::1:2:3'), isEmpty);
    });

    test('caps lines and their length', () {
      final raw = List.generate(80, (i) => '#$i f (package:a/b.dart:$i)').join('\n');
      expect(scrubStack(raw).length, maxStackLines);
      final long = 'package:a/${'x' * 500}.dart';
      expect(scrubStack(long).single.length, maxLineLength);
    });

    test('error type is the class name only', () {
      expect(scrubErrorType('StateError'), 'StateError');
      expect(scrubErrorType('_TypeError'), '_TypeError');
      expect(scrubErrorType('List<Channel>'), 'List');
      expect(scrubErrorType('java.lang.IllegalStateException'),
          'java.lang.IllegalStateException');
      expect(scrubErrorType('http://x.com/y'), 'http');
      expect(scrubErrorType('  '), 'Unknown');
      expect(scrubErrorType('10.0.0.1'), 'Unknown');
    });

    test('short text is printable, capped and never an address', () {
      expect(scrubShortText('Google Chromecast'), 'Google Chromecast');
      expect(scrubShortText('10.0.0.5'), 'unknown');
      expect(scrubShortText('a' * 200).length, 60);
      expect(scrubShortText(''), 'unknown');
    });
  });

  group('report', () {
    test('contains exactly the documented fields, nothing else', () {
      final r = StatsReport.build(
        facts: _facts,
        now: DateTime.utc(2026, 11, 3, 23, 59, 59),
        kind: ReportKind.crash,
        errorType: 'StateError',
        rawStack: '#0 f (package:open_iptv/a.dart:1:1)',
      ).toJson();
      expect(r.keys.toSet(),
          {'v', 'app', 'platform', 'os', 'device', 'day', 'kind', 'error', 'stack'});
      expect(r['v'], 1);
      expect(r['day'], '2026-11-03'); // date only, no time
      expect(r['kind'], 'crash');
      expect(r['platform'], 'android-tv');
    });

    test('a hang keeps only code frames and no addresses', () {
      final r = StatsReport.build(
        facts: _facts,
        now: DateTime.utc(2026, 11, 6),
        kind: ReportKind.hang,
        errorType: 'ANR',
        rawStack: '  at android.os.MessageQueue.nativePollOnce(Native Method)\n'
            '  at com.openiptv.app.X.y(X.kt:1)\n  at /data/app/~~abc/base.apk',
      ).toJson();
      expect(r['kind'], 'hang');
      expect(r['error'], 'ANR');
      expect((r['stack'] as List).length, 2);
    });

    test('free text is scrubbed even if the caller passes junk', () {
      final r = StatsReport.build(
        facts: const DeviceFacts(
            app: 'http://evil', platform: 'whatever', os: 1, device: '1.2.3.4'),
        now: DateTime.utc(2026, 1, 2),
        kind: ReportKind.nativeCrash,
        errorType: 'Boom: password=hunter2 at http://x',
        rawStack: 'at com.openiptv.app.X.y(X.kt:1) https://secret.example/z',
      ).toJson();
      final text = jsonEncode(r);
      expect(text.contains('hunter2'), isFalse);
      expect(text.contains('http'), isFalse);
      expect(text.contains('1.2.3.4'), isFalse);
      expect(r['platform'], 'android');
      expect(r['kind'], 'native-crash');
    });
  });

  group('consent', () {
    test('only the exact value "on" counts as on', () {
      expect(parseStatsChoice(null), StatsChoice.unset);
      expect(parseStatsChoice('ON'), StatsChoice.unset);
      expect(parseStatsChoice('yes'), StatsChoice.unset);
      expect(parseStatsChoice('on'), StatsChoice.on);
      expect(parseStatsChoice('off'), StatsChoice.off);
    });
  });

  group('queue', () {
    late Directory dir;
    late ReportQueue q;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('otv_stats');
      q = ReportQueue(File('${dir.path}/t/queue.json'));
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('keeps the newest maxQueuedReports', () async {
      for (var i = 0; i < maxQueuedReports + 5; i++) {
        await q.add({'i': i});
      }
      final all = await q.read();
      expect(all.length, maxQueuedReports);
      expect(all.first['i'], 5);
      expect(all.last['i'], maxQueuedReports + 4);
    });

    test('clear removes everything; a corrupt file reads as empty', () async {
      await q.add({'a': 1});
      await q.clear();
      expect(await q.read(), isEmpty);
      await q.file.parent.create(recursive: true);
      await q.file.writeAsString('not json');
      expect(await q.read(), isEmpty);
    });
  });

  group('sender', () {
    test('keeps only reports that should be retried', () async {
      var n = 0;
      final client = MockClient((req) async {
        n++;
        expect(req.headers['content-type'], contains('application/json'));
        expect(req.headers.containsKey('cookie'), isFalse);
        return switch (n) {
          1 => http.Response('', 200),
          2 => http.Response('', 400), // never acceptable: dropped
          _ => http.Response('', 503), // try again later: kept
        };
      });
      final failed = await sendReports([
        {'a': 1},
        {'a': 2},
        {'a': 3},
      ], client: client, endpoint: 'https://example.test/report');
      expect(failed, [
        {'a': 3}
      ]);
    });

    test('network errors keep the report', () async {
      final client = MockClient((_) async => throw const SocketException('x'));
      final failed = await sendReports([
        {'a': 1}
      ], client: client, endpoint: 'https://example.test/report');
      expect(failed.length, 1);
    });

    test('the receiver address is the project Worker over HTTPS', () {
      expect(statsEndpoint, startsWith('https://openiptv-stats.'));
      expect(statsEndpoint, endsWith('.workers.dev/report'));
      expect(statsEndpointConfigured, isTrue);
    });
  });
}
