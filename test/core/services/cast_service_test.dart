import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/cast_service.dart';

void main() {
  group('castCandidates', () {
    test('Xtream live .ts tries the HLS variant first', () {
      expect(
        castCandidates('http://host:8080/live/user/pass/123.ts', live: true),
        [
          'http://host:8080/live/user/pass/123.m3u8',
          'http://host:8080/live/user/pass/123.ts',
        ],
      );
    });

    test('other links are cast as they are', () {
      const hls = 'https://cdn.example.com/stream/index.m3u8';
      const movie = 'http://host/movie/user/pass/9.mp4';
      const catchup = 'http://host/timeshift/user/pass/60/2026-10-05:10-00/1.ts';
      expect(castCandidates(hls, live: true), [hls]);
      expect(castCandidates(movie, live: false), [movie]);
      expect(castCandidates(catchup, live: false), [catchup]);
    });

    test('a .ts link that is not live (e.g. a recording) is left alone', () {
      const url = 'http://host/live/user/pass/123.ts';
      expect(castCandidates(url, live: false), [url]);
    });
  });

  test('castContentType reads the extension', () {
    expect(castContentType('http://h/a/index.m3u8?token=1'),
        'application/x-mpegURL');
    expect(castContentType('http://h/live/u/p/1.ts'), 'video/mp2t');
    expect(castContentType('http://h/movie/u/p/1.MKV'), 'video/x-matroska');
    expect(castContentType('http://h/movie/u/p/1.mp4'), 'video/mp4');
    expect(castContentType('http://h/stream'), 'video/mp4');
  });

  test('CastStatus parses the native state map', () {
    final s = CastStatus.fromMap(const {
      'supported': true,
      'available': true,
      'session': 'connected',
      'device': 'Living Room TV',
      'devices': [
        {'id': 'a', 'name': 'Living Room TV'},
      ],
      'playerState': 'playing',
      'positionMs': 61000,
      'durationMs': 3600000,
      'volume': 0.4,
    });
    expect(s.connected, isTrue);
    expect(s.device, 'Living Room TV');
    expect(s.devices.single.name, 'Living Room TV');
    expect(s.playerState, CastPlayerState.playing);
    expect(s.position, const Duration(seconds: 61));
    expect(s.duration, const Duration(hours: 1));

    final empty = CastStatus.fromMap(const {});
    expect(empty.connected, isFalse);
    expect(empty.available, isFalse);
    expect(empty.playerState, CastPlayerState.idle);
  });
}
