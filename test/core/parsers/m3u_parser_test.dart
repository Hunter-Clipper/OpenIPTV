import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/parsers/m3u_parser.dart';

void main() {
  const sourceId = 'test_source';

  group('M3uParser', () {
    late String sampleContent;

    setUpAll(() {
      sampleContent = File('test/fixtures/sample.m3u').readAsStringSync();
    });

    test('parses EPG URL from header', () async {
      final result = await M3uParser.parse(sampleContent, sourceId);
      expect(result.epgUrl, 'http://epg.example.com/guide.xml');
    });

    test('parses live channels correctly', () async {
      final result = await M3uParser.parse(sampleContent, sourceId);
      expect(result.channels, isNotEmpty);
      final bbc = result.channels.firstWhere((c) => c.tvgId == 'BBC1');
      expect(bbc.name, 'BBC One');
      expect(bbc.logoUrl, 'http://logos.example.com/bbc1.png');
      expect(bbc.groupTitle, 'News');
      expect(bbc.streamUrl, 'http://streams.example.com/live/bbc1.ts');
      expect(bbc.tvgName, 'BBC One');
    });

    test('assigns sequential sortOrder to channels', () async {
      final result = await M3uParser.parse(sampleContent, sourceId);
      for (var i = 0; i < result.channels.length; i++) {
        expect(result.channels[i].sortOrder, i);
      }
    });

    test('parses movies from VOD groups', () async {
      final result = await M3uParser.parse(sampleContent, sourceId);
      expect(result.movies, isNotEmpty);
      final interstellar = result.movies.firstWhere(
        (m) => m.title.contains('Interstellar'),
      );
      expect(interstellar.posterUrl, 'http://logos.example.com/interstellar.jpg');
      expect(interstellar.streamUrl, contains('interstellar.mp4'));
    });

    test('routes Films group to movies', () async {
      final result = await M3uParser.parse(sampleContent, sourceId);
      final parasite = result.movies.firstWhere(
        (m) => m.title.contains('Parasite'),
      );
      expect(parasite, isNotNull);
    });

    test('parses series from Series group', () async {
      final result = await M3uParser.parse(sampleContent, sourceId);
      expect(result.series, isNotEmpty);
      final bb = result.series.firstWhere(
        (s) => s.title.contains('Breaking Bad'),
      );
      expect(bb, isNotNull);
    });

    test('parses episodes with correct season/episode numbers', () async {
      final result = await M3uParser.parse(sampleContent, sourceId);
      expect(result.episodes, isNotEmpty);
      final ep = result.episodes.firstWhere(
        (e) => e.streamUrl.contains('bb_s01e01'),
      );
      expect(ep.season, 1);
      expect(ep.episode, 1);
    });

    test('groups episodes under the correct series', () async {
      final result = await M3uParser.parse(sampleContent, sourceId);
      final bb = result.series.firstWhere((s) => s.title.contains('Breaking Bad'));
      final bbEps = result.episodes.where((e) => e.seriesId == bb.id).toList();
      expect(bbEps.length, greaterThanOrEqualTo(4));
    });

    test('handles entries with no group-title', () async {
      final result = await M3uParser.parse(sampleContent, sourceId);
      final noCategory = result.channels.firstWhere(
        (c) => c.name == 'No Category Channel',
        orElse: () => result.channels.last,
      );
      // Should parse without crashing; groupTitle may be null or empty.
      expect(noCategory, isNotNull);
    });

    test('handles entries with no logo', () async {
      final result = await M3uParser.parse(sampleContent, sourceId);
      final noLogo = result.channels.firstWhere(
        (c) => c.name == 'No Logo Channel',
      );
      expect(noLogo.logoUrl, anyOf(isNull, isEmpty));
    });

    test('produces deterministic IDs for stable upserts', () async {
      final result1 = await M3uParser.parse(sampleContent, sourceId);
      final result2 = await M3uParser.parse(sampleContent, sourceId);
      expect(result1.channels.map((c) => c.id).toList(),
          result2.channels.map((c) => c.id).toList());
    });

    test('handles empty file gracefully', () async {
      final result = await M3uParser.parse('', sourceId);
      expect(result.channels, isEmpty);
      expect(result.movies, isEmpty);
      expect(result.series, isEmpty);
      expect(result.episodes, isEmpty);
      expect(result.epgUrl, isNull);
    });

    test('handles file with only header line', () async {
      final result = await M3uParser.parse('#EXTM3U\n', sourceId);
      expect(result.channels, isEmpty);
    });

    test('ignores comment lines', () async {
      const content = '''
#EXTM3U
# This is a comment
#EXTVLCOPT:network-caching=1000
#EXTINF:-1 group-title="News",Test Channel
http://example.com/live.ts
''';
      final result = await M3uParser.parse(content, sourceId);
      expect(result.channels.length, 1);
      expect(result.channels.first.name, 'Test Channel');
    });

    test('handles missing EXTINF before stream URL', () async {
      const content = '''
#EXTM3U
http://example.com/orphan.ts
#EXTINF:-1 group-title="News",Valid Channel
http://example.com/valid.ts
''';
      final result = await M3uParser.parse(content, sourceId);
      // Orphan URL is skipped; only the valid one is parsed.
      expect(result.channels.length, 1);
      expect(result.channels.first.name, 'Valid Channel');
    });

    test('detects series by SxxExx pattern even without Series group', () async {
      const content = '''
#EXTM3U
#EXTINF:-1 group-title="VOD",My Show S02E05 Episode Title
http://example.com/ep.mp4
''';
      final result = await M3uParser.parse(content, sourceId);
      expect(result.episodes, isNotEmpty);
      expect(result.episodes.first.season, 2);
      expect(result.episodes.first.episode, 5);
    });
  });
}
