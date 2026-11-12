import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/parsers/xmltv_parser.dart';
import 'package:open_iptv/core/services/guide_fetch.dart';

String stamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final u = t.toUtc();
  return '${u.year}${two(u.month)}${two(u.day)}${two(u.hour)}${two(u.minute)}${two(u.second)} +0000';
}

String guideXml() {
  final now = DateTime.now();
  final b = StringBuffer('<?xml version="1.0"?><tv>');
  b.write('<channel id="BBCOne.uk"><display-name lang="en">UK - BBC One</display-name></channel>');
  b.write('<channel id="WNBC-DT.us"><display-name>WNBC-DT</display-name><display-name>Other</display-name></channel>');
  b.write('<channel id="NoName.us"></channel>');
  for (final c in ['BBCOne.uk', 'WNBC-DT.us']) {
    for (var i = 0; i < 3; i++) {
      final s = now.add(Duration(hours: i));
      b.write('<programme start="${stamp(s)}" stop="${stamp(s.add(const Duration(hours: 1)))}" channel="$c">'
          '<title>$c show $i</title><desc>about $i</desc></programme>');
    }
  }
  b.write('</tv>');
  return b.toString();
}

void main() {
  late HttpServer server;
  late Directory tmp;
  late String base;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('guide_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    final xml = utf8.encode(guideXml());
    server.listen((req) async {
      final res = req.response;
      switch (req.uri.path) {
        case '/plain.xml':
          res.add(xml);
        case '/guide.xml.gz':
          res.add(GZipEncoder().encode(xml)!);
        case '/guide.zip':
          final a = Archive()..addFile(ArchiveFile('inner/guide.xml', xml.length, xml));
          res.add(ZipEncoder().encode(a)!);
        case '/page':
          res.write('<!DOCTYPE html><html><body>Too many requests</body></html>');
        case '/empty':
          res.write('<tv></tv>');
        default:
          res.statusCode = 404;
      }
      await res.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await tmp.delete(recursive: true);
  });

  for (final path in ['/plain.xml', '/guide.xml.gz', '/guide.zip']) {
    test('reads the channel list from $path', () async {
      final ch = await fetchGuideChannels('$base$path', tmp.path);
      expect(ch.map((c) => c.id), ['BBCOne.uk', 'WNBC-DT.us', 'NoName.us']);
      expect(ch.first.name, 'UK - BBC One');
      expect(ch[1].name, 'WNBC-DT'); // the first display-name only
      expect(ch.last.name, '');
    });

    test('keeps only the programmes of the wanted channels from $path',
        () async {
      final ps = await fetchGuideProgrammes('$base$path', tmp.path, {'WNBC-DT.us'},
          pastWindow: const Duration(hours: 1),
          daysAhead: 5,
          keepDescriptions: true);
      expect(ps.map((p) => p.channelId).toSet(), {'WNBC-DT.us'});
      expect(ps, hasLength(3));
      expect(ps.first.description, startsWith('about'));
    });
  }

  test('descriptions can be left out', () async {
    final ps = await fetchGuideProgrammes('$base/plain.xml', tmp.path, {'BBCOne.uk'},
        pastWindow: const Duration(hours: 1), daysAhead: 5, keepDescriptions: false);
    expect(ps.every((p) => p.description == null), isTrue);
  });

  test('unpacked zips leave nothing behind', () async {
    await fetchGuideChannels('$base/guide.zip', tmp.path);
    expect(tmp.listSync(), isEmpty);
  });

  test('an error page, an empty guide and a missing file are failures', () async {
    await expectLater(fetchGuideChannels('$base/page', tmp.path), throwsA(anything));
    await expectLater(fetchGuideChannels('$base/empty', tmp.path), throwsA(anything));
    await expectLater(fetchGuideChannels('$base/nope', tmp.path),
        throwsA(predicate((e) => '$e'.contains('http_404'))));
  });

  test('channel parsing stops at the first programme', () async {
    final b = StringBuffer('<tv><channel id="a"><display-name>A</display-name></channel>');
    b.write('<programme start="20260101000000 +0000" stop="20260101010000 +0000" channel="a"><title>x</title></programme>');
    // Garbage after the first programme would throw if it were read.
    b.write('<<<not xml');
    final got = await XmltvParser.parseChannels(Stream.value(b.toString())).toList();
    expect(got.map((c) => c.id), ['a']);
  });
}
