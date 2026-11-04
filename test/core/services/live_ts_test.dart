import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/playback_service.dart';

void main() {
  group('PlaybackService.isLiveTs', () {
    test('a live channel .ts link qualifies', () {
      expect(PlaybackService.isLiveTs('http://host:80/live/u/p/123.ts'), isTrue);
      expect(PlaybackService.isLiveTs('http://host/live/u/p/123.TS?x=1'), isTrue);
    });

    test('catch-up, VOD and HLS links do not', () {
      expect(PlaybackService.isLiveTs('http://host/timeshift/u/p/60/2026-11-04:10-00/123.ts'), isFalse);
      expect(PlaybackService.isLiveTs('http://host/movie/u/p/55.mp4'), isFalse);
      expect(PlaybackService.isLiveTs('http://host/series/u/p/55.ts'), isFalse);
      expect(PlaybackService.isLiveTs('http://host/live/u/p/123.m3u8'), isFalse);
      expect(PlaybackService.isLiveTs('not a url'), isFalse);
    });
  });
}
