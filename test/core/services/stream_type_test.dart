import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/parsers/xtream_client.dart';
import 'package:open_iptv/core/services/playback_service.dart';

void main() {
  group('PlaybackService.detectStreamType', () {
    StreamType t(String url) => PlaybackService.detectStreamType(url);

    test('reads the file extension of the path', () {
      expect(t('http://host/live/u/p/1.m3u8'), StreamType.hls);
      expect(t('http://host/live/u/p/1.ts'), StreamType.mpegTs);
      expect(t('http://host/movie/u/p/1.mp4'), StreamType.progressive);
      expect(t('http://host/movie/u/p/1.MKV'), StreamType.progressive);
      expect(t('http://host/live/u/p/1'), StreamType.auto);
    });

    test('an hls path segment means HLS', () {
      expect(t('http://host/hls/stream/42'), StreamType.hls);
    });

    test('the host never decides', () {
      expect(t('http://x.tsc.com/live/u/p/1'), StreamType.auto);
      expect(t('http://iptv.tsn.io/movie/u/p/1.mp4'), StreamType.progressive);
      expect(t('http://cdn.tstream.net/live/u/p/1'), StreamType.auto);
      expect(t('http://hls.example.com/live/u/p/1.ts'), StreamType.mpegTs);
    });

    test('the query string is ignored', () {
      expect(t('http://host/live/1?token=a.ts'), StreamType.auto);
      expect(t('http://host/live/1.m3u8?token=a.ts'), StreamType.hls);
    });
  });

  group('XtreamClient.liveExtFor', () {
    test('a chosen format wins', () {
      expect(XtreamClient.liveExtFor('hls', ['ts']), 'm3u8');
      expect(XtreamClient.liveExtFor('ts', ['m3u8']), 'ts');
    });

    test('auto prefers TS, uses HLS only when TS is not offered', () {
      expect(XtreamClient.liveExtFor('auto', ['ts', 'm3u8']), 'ts');
      expect(XtreamClient.liveExtFor('auto', ['M3U8']), 'm3u8');
      expect(XtreamClient.liveExtFor('auto', ['rtmp']), 'ts');
      expect(XtreamClient.liveExtFor('auto', const []), 'ts');
    });
  });
}
