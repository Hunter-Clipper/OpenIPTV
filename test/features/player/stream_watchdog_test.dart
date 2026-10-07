import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/native_video_player.dart';
import 'package:open_iptv/features/player/stream_watchdog.dart';

NativeVideoPlayerState _s({
  int posMs = 0,
  bool playing = true,
  bool playWhenReady = true,
  bool buffering = false,
  bool completed = false,
  bool video = true,
}) =>
    NativeVideoPlayerState(
      position: Duration(milliseconds: posMs),
      duration: Duration.zero,
      playing: playing,
      playWhenReady: playWhenReady,
      buffering: buffering,
      completed: completed,
      videoWidth: video ? 1920 : 0,
      videoHeight: video ? 1080 : 0,
    );

/// Drives a watchdog with a fake clock, one check per 500 ms like the
/// player screen's timer.
class _Harness {
  _Harness({this.live = true});

  final bool live;
  final dog = StreamWatchdog();
  var now = DateTime(2026, 1, 1);
  var openCount = 1;
  var pos = 0;
  final actions = <WatchdogAction>[];

  WatchdogAction tick(NativeVideoPlayerState s, {bool active = true}) {
    now = now.add(const Duration(milliseconds: 500));
    final a = dog.check(s,
        now: now, openCount: openCount, live: live, active: active);
    actions.add(a);
    return a;
  }

  /// Plays smoothly for [seconds].
  void play(double seconds) {
    for (var i = 0; i < seconds * 2; i++) {
      pos += 500;
      tick(_s(posMs: pos));
    }
  }

  /// Engine stuck (not moving) for [seconds]; returns the first non-none
  /// action, if any.
  WatchdogAction? freeze(double seconds, {bool buffering = true}) {
    for (var i = 0; i < seconds * 2; i++) {
      final a = tick(_s(posMs: pos, playing: false, buffering: buffering));
      if (a != WatchdogAction.none) return a;
    }
    return null;
  }

  void reopen() {
    openCount++;
    pos = 0;
  }
}

void main() {
  test('smooth playback is left alone and clears loading', () {
    final h = _Harness()..play(5);
    expect(h.actions.where((a) => a != WatchdogAction.none), isEmpty);
    expect(h.dog.loading, isFalse);
    expect(h.dog.everPlayed, isTrue);
  });

  test('a mid-stream freeze reconnects after about 4 seconds', () {
    final h = _Harness()..play(5);
    final before = h.now;
    final a = h.freeze(10);
    expect(a, WatchdogAction.reconnect);
    final waited = h.now.difference(before);
    expect(waited, greaterThanOrEqualTo(const Duration(seconds: 4)));
    expect(waited, lessThanOrEqualTo(const Duration(milliseconds: 4500)));
  });

  test('a short hiccup does not reconnect or flash the loading screen', () {
    final h = _Harness()..play(5);
    expect(h.freeze(1), isNull);
    expect(h.dog.loading, isFalse);
    h.play(2);
    expect(h.actions.where((a) => a != WatchdogAction.none), isEmpty);
  });

  test('loading shows once a stall passes ~1 s', () {
    final h = _Harness()..play(5);
    h.freeze(1.5);
    expect(h.dog.loading, isTrue);
    h.play(1);
    expect(h.dog.loading, isFalse);
  });

  test('a frozen "ready" engine (no buffering flag) still counts as stalled',
      () {
    final h = _Harness()..play(5);
    // Decoder stuck: ExoPlayer claims ready/playing but the position
    // never moves.
    WatchdogAction? a;
    for (var i = 0; i < 20 && a == null; i++) {
      final r = h.tick(_s(posMs: h.pos, playing: true));
      if (r != WatchdogAction.none) a = r;
    }
    expect(a, WatchdogAction.reconnect);
  });

  test('pausing is never a stall', () {
    final h = _Harness()..play(5);
    for (var i = 0; i < 120; i++) {
      expect(h.tick(_s(posMs: h.pos, playing: false, playWhenReady: false)),
          WatchdogAction.none);
    }
    expect(h.dog.loading, isFalse);
    // Resuming restarts the clock: no instant reconnect.
    expect(h.tick(_s(posMs: h.pos, playing: false, buffering: true)),
        WatchdogAction.none);
  });

  test('a live stream that "ends" reconnects; VOD ending does not', () {
    final live = _Harness()..play(5);
    expect(live.tick(_s(posMs: live.pos, playing: false, completed: true)),
        WatchdogAction.reconnect);

    final vod = _Harness(live: false)..play(5);
    for (var i = 0; i < 30; i++) {
      expect(vod.tick(_s(posMs: vod.pos, playing: false, completed: true)),
          WatchdogAction.none);
    }
  });

  test('ended live does not reconnect again before the new stream reports',
      () {
    final h = _Harness()..play(5);
    expect(h.tick(_s(posMs: h.pos, playing: false, completed: true)),
        WatchdogAction.reconnect);
    h.reopen();
    // Stale "ended" state from before the reopen lands right after it.
    expect(h.tick(_s(posMs: 0, playing: false, completed: true)),
        WatchdogAction.none);
  });

  test('connecting gets 8 seconds before the first frame', () {
    final h = _Harness();
    final before = h.now;
    final a = h.freeze(20);
    expect(a, WatchdogAction.reconnect);
    expect(h.now.difference(before),
        greaterThanOrEqualTo(const Duration(seconds: 8)));
  });

  test('a stream that never plays gives up after 5 attempts', () {
    final h = _Harness();
    var reconnects = 0;
    WatchdogAction? last;
    for (var round = 0; round < 10; round++) {
      last = h.freeze(20);
      if (last == WatchdogAction.reconnect) {
        reconnects++;
        h.reopen();
      } else {
        break;
      }
    }
    expect(reconnects, 5);
    expect(last, WatchdogAction.giveUp);
  });

  test('a stream that played keeps reconnecting, backing off to 15 s', () {
    final h = _Harness()..play(5);
    expect(h.freeze(10), WatchdogAction.reconnect);
    var gap = Duration.zero;
    for (var round = 0; round < 20; round++) {
      h.reopen();
      final before = h.now;
      final a = h.freeze(30);
      expect(a, WatchdogAction.reconnect, reason: 'round $round');
      gap = h.now.difference(before);
      // The window starts when the new connection is first checked, up to
      // one 500 ms tick after the reconnect.
      expect(gap, lessThanOrEqualTo(const Duration(milliseconds: 15500)));
    }
    expect(gap, greaterThanOrEqualTo(const Duration(seconds: 15)));
  });

  test('recovering resets the attempt count once playback is stable', () {
    final h = _Harness()..play(5);
    h.freeze(10);
    h.reopen();
    h.freeze(20);
    h.reopen();
    expect(h.dog.attempts, 2);
    h.play(4);
    expect(h.dog.attempts, 0);
    expect(h.dog.loading, isFalse);
  });

  test('a non-permanent engine error reconnects immediately', () {
    final h = _Harness()..play(5);
    expect(h.dog.onError(h.now), WatchdogAction.reconnect);
    expect(h.dog.loading, isTrue);
  });

  test('inactive (casting, resume prompt) never acts', () {
    final h = _Harness()..play(2);
    for (var i = 0; i < 60; i++) {
      expect(
          h.tick(_s(posMs: h.pos, playing: false, buffering: true),
              active: false),
          WatchdogAction.none);
    }
    // Back to active: the clock starts fresh.
    expect(h.tick(_s(posMs: h.pos, playing: false, buffering: true)),
        WatchdogAction.none);
  });

  test('audio-only streams count as playing after a few seconds', () {
    final h = _Harness();
    for (var i = 0; i < 8; i++) {
      h.pos += 500;
      h.tick(_s(posMs: h.pos, video: false));
    }
    expect(h.dog.everPlayed, isTrue);
    expect(h.dog.loading, isFalse);
  });

  test('before the first frame, loading stays up until a picture arrives',
      () {
    final h = _Harness();
    h.pos += 500;
    h.tick(_s(posMs: h.pos, video: false)); // sound but no picture yet
    expect(h.dog.loading, isTrue);
    h.pos += 500;
    h.tick(_s(posMs: h.pos)); // first frame
    expect(h.dog.loading, isFalse);
  });
}
