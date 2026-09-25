import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/episode.dart';

Episode _ep(String title, {int season = 1, int episode = 1}) => Episode(
      id: 'e',
      seriesId: 's',
      sourceId: 'src',
      season: season,
      episode: episode,
      title: title,
      streamUrl: 'http://x',
    );

void main() {
  group('Episode.displayTitle', () {
    test('replaces a title that just restates its SxxEyy code', () {
      expect(_ep('EN - Friends - UNCUT (1994) - S01E01').displayTitle,
          'Episode 1');
      expect(_ep('Show s2e10', season: 2, episode: 10).displayTitle,
          'Episode 10');
    });

    test('keeps real titles', () {
      expect(_ep('The One Where Monica Gets a Roommate').displayTitle,
          'The One Where Monica Gets a Roommate');
    });

    test('does not match a different episode number prefix', () {
      // S01E10 must not count as restating S01E1.
      expect(_ep('Show - S01E10', episode: 1).displayTitle, 'Show - S01E10');
    });

    test('falls back for an empty title', () {
      expect(_ep('  ', episode: 3).displayTitle, 'Episode 3');
    });
  });
}
