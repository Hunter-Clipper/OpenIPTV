import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/parsers/xmltv_parser.dart';

void main() {
  group('XmltvParser', () {
    late String sampleXml;
    // The fixture's dates are anchored to "today + 2 days" rather than a
    // fixed calendar date, so these tests don't silently start failing once
    // real time moves the fixture's hardcoded dates outside the parser's
    // 5-day/1-hour window (as happened when the fixture was written against
    // June 2026 and kept using that date well past it).
    late DateTime anchor;

    setUpAll(() {
      anchor = DateTime.now().toUtc().add(const Duration(days: 2));
      final tomorrow = anchor.add(const Duration(days: 1));
      final outsideWindow = anchor.add(const Duration(days: 5));
      sampleXml = File('test/fixtures/sample.xml')
          .readAsStringSync()
          .replaceAll('20260622', _fmtDate(anchor))
          .replaceAll('20260623', _fmtDate(tomorrow))
          .replaceAll('20260627', _fmtDate(outsideWindow));
    });

    Stream<String> stream(String content) => Stream.value(content);

    test('parses programmes from sample fixture', () async {
      final programmes = await XmltvParser.parse(stream(sampleXml)).toList();
      expect(programmes, isNotEmpty);
    });

    test('parses title correctly', () async {
      final programmes = await XmltvParser.parse(stream(sampleXml)).toList();
      final eastenders =
          programmes.firstWhere((p) => p.title == 'EastEnders');
      expect(eastenders.channelId, 'BBC1');
      expect(eastenders.category, 'Drama');
      expect(eastenders.episodeNum, isNotNull);
    });

    test('parses description correctly', () async {
      final programmes = await XmltvParser.parse(stream(sampleXml)).toList();
      final news =
          programmes.firstWhere((p) => p.title == "The Six O'Clock News");
      expect(news.description, isNotNull);
      expect(news.description, contains('BBC News'));
    });

    test('parses start and end times correctly', () async {
      final programmes = await XmltvParser.parse(stream(sampleXml)).toList();
      final news =
          programmes.firstWhere((p) => p.title == "The Six O'Clock News");
      expect(news.start, DateTime.utc(anchor.year, anchor.month, anchor.day, 18, 0, 0));
      expect(news.end, DateTime.utc(anchor.year, anchor.month, anchor.day, 19, 0, 0));
    });

    test('handles +0100 timezone offset correctly', () async {
      final programmes = await XmltvParser.parse(stream(sampleXml)).toList();
      final tzTest = programmes
          .firstWhere((p) => p.title == 'Timezone Test Programme');
      // 21:30 +0100 = 20:30 UTC
      expect(tzTest.start,
          DateTime.utc(anchor.year, anchor.month, anchor.day, 20, 30, 0));
    });

    test('handles -0500 timezone offset correctly', () async {
      final programmes = await XmltvParser.parse(stream(sampleXml)).toList();
      final tzTest = programmes
          .firstWhere((p) => p.title == 'Negative Timezone Test');
      // 21:30 -0500 = 02:30 UTC next day
      final nextDay = anchor.add(const Duration(days: 1));
      expect(tzTest.start,
          DateTime.utc(nextDay.year, nextDay.month, nextDay.day, 2, 30, 0));
    });

    test('filters out programmes beyond 5-day window', () async {
      final programmes = await XmltvParser.parse(stream(sampleXml)).toList();
      final outside = programmes
          .where((p) => p.title == 'Programme Outside Window')
          .toList();
      expect(outside, isEmpty);
    });

    test('includes programmes within 5-day window', () async {
      final programmes = await XmltvParser.parse(stream(sampleXml)).toList();
      final tomorrow = programmes
          .where((p) => p.title == "Tomorrow's Show")
          .toList();
      expect(tomorrow, isNotEmpty);
    });

    test('handles missing description gracefully', () async {
      final programmes = await XmltvParser.parse(stream(sampleXml)).toList();
      final noDesc =
          programmes.firstWhere((p) => p.title == 'No Description Programme');
      expect(noDesc.description, isNull);
      expect(noDesc.category, isNull);
    });

    test('handles empty XML gracefully', () async {
      const empty = '<?xml version="1.0"?><tv></tv>';
      final programmes = await XmltvParser.parse(stream(empty)).toList();
      expect(programmes, isEmpty);
    });

    test('handles malformed timestamp gracefully', () async {
      const xml = '''<?xml version="1.0"?>
<tv>
  <programme start="INVALID" stop="ALSOINVALID" channel="TEST">
    <title>Bad Times</title>
  </programme>
</tv>''';
      // Should not throw; programme with unparseable times is dropped.
      final programmes = await XmltvParser.parse(stream(xml)).toList();
      expect(programmes.where((p) => p.title == 'Bad Times'), isEmpty);
    });

    test('isLive returns true for current programme', () async {
      final now = DateTime.now();
      final start = now.subtract(const Duration(minutes: 10));
      final end = now.add(const Duration(minutes: 50));
      final xml = '''<?xml version="1.0"?>
<tv>
  <programme start="${_fmt(start)} +0000" stop="${_fmt(end)} +0000" channel="TEST">
    <title>Live Right Now</title>
  </programme>
</tv>''';
      final programmes = await XmltvParser.parse(stream(xml)).toList();
      expect(programmes, isNotEmpty);
      expect(programmes.first.isLive, isTrue);
    });

    test('parses multiple channels', () async {
      final programmes = await XmltvParser.parse(stream(sampleXml)).toList();
      final channelIds = programmes.map((p) => p.channelId).toSet();
      expect(channelIds, containsAll(['BBC1', 'ITV1', 'CH4']));
    });
  });
}

String _fmt(DateTime dt) {
  final utc = dt.toUtc();
  return '${utc.year}'
      '${utc.month.toString().padLeft(2, '0')}'
      '${utc.day.toString().padLeft(2, '0')}'
      '${utc.hour.toString().padLeft(2, '0')}'
      '${utc.minute.toString().padLeft(2, '0')}'
      '${utc.second.toString().padLeft(2, '0')}';
}

String _fmtDate(DateTime dt) {
  final utc = dt.toUtc();
  return '${utc.year}'
      '${utc.month.toString().padLeft(2, '0')}'
      '${utc.day.toString().padLeft(2, '0')}';
}
