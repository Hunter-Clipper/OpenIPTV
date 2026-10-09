import 'package:open_iptv/core/services/native_video_player.dart';

/// What the player screen should do after a [StreamWatchdog] check.
enum WatchdogAction {
  none,

  /// Reopen the stream now (live: at the live edge; VOD: where it was).
  reconnect,

  /// Stop trying and show the error screen.
  giveUp,
}

/// Decides when a stream that should be playing has stopped and needs
/// reconnecting. The player screen feeds it the engine state on every
/// update and on a short timer, so it notices a freeze even when the engine
/// itself goes quiet.
///
/// "Playing" is measured by the position moving while the player is meant
/// to be playing ([NativeVideoPlayerState.playWhenReady]). A pause never
/// counts as a stall; buffering, a decoder stuck on the last frame, an idle
/// engine after an error, or a live stream that "ended" all do.
///
/// * While (re)connecting, a stream gets [connectLimit] to start moving.
/// * Once it has moved, a freeze longer than [freezeLimit] reconnects.
/// * A stream that never played gives up after [maxAttemptsBeforePlaying]
///   tries (a dead channel shouldn't spin forever). One that has played
///   keeps reconnecting — after the first few tries, at most every
///   [maxBackoff] — until it comes back or the user leaves.
class StreamWatchdog {
  StreamWatchdog({
    this.freezeLimit = const Duration(seconds: 4),
    this.connectLimit = const Duration(seconds: 8),
    this.showLoadingAfter = const Duration(milliseconds: 1200),
    this.maxAttemptsBeforePlaying = 5,
    this.maxBackoff = const Duration(seconds: 15),
  });

  final Duration freezeLimit;
  final Duration connectLimit;

  /// A short hiccup isn't worth an overlay; a longer one shows "loading".
  final Duration showLoadingAfter;
  final int maxAttemptsBeforePlaying;
  final Duration maxBackoff;

  /// Reconnects since playback last ran smoothly for a few seconds.
  int get attempts => _attempts;
  int _attempts = 0;

  /// Frames have moved at least once for this title/channel.
  bool get everPlayed => _everPlayed;
  bool _everPlayed = false;

  /// The screen should show its loading/reconnecting state.
  bool get loading => _loading;
  bool _loading = true;

  int? _openCount;
  Duration? _lastPosition;
  DateTime? _movedAt; // last time the position moved (or a window started)
  DateTime? _smoothSince;
  DateTime? _reconnectedAt;
  bool _movedSinceOpen = false;

  static const _stableAfter = Duration(seconds: 3);

  /// Starts over for a new title or a manual "Try again".
  void reset() {
    _attempts = 0;
    _everPlayed = false;
    _loading = true;
    _openCount = null;
    _lastPosition = null;
    _movedAt = null;
    _smoothSince = null;
    _reconnectedAt = null;
    _movedSinceOpen = false;
  }

  /// Checks [s]. [openCount] is the playback service's open counter, so a
  /// reopen restarts the connect window. [live] streams reconnect when they
  /// "end"; VOD ending is a real ending. [active] is false while there's
  /// nothing to watch over (casting, the error screen, a resume prompt).
  WatchdogAction check(
    NativeVideoPlayerState s, {
    required DateTime now,
    required int openCount,
    required bool live,
    bool active = true,
  }) {
    if (openCount != _openCount) {
      _openCount = openCount;
      _movedSinceOpen = false;
      _lastPosition = null;
      _movedAt = now;
      _smoothSince = null;
    }
    _movedAt ??= now;
    if (!active) {
      _movedAt = now;
      return WatchdogAction.none;
    }

    if (s.completed) {
      if (!live) {
        _loading = false;
        return WatchdogAction.none;
      }
      // A live stream doesn't end: the provider dropped the connection.
      // (Not again within a second of a reconnect — the new connection
      // hasn't reported in yet.)
      _loading = true;
      final since = _reconnectedAt;
      if (since != null &&
          now.difference(since) < const Duration(seconds: 1)) {
        return WatchdogAction.none;
      }
      return _reconnect(now);
    }

    if (!s.playWhenReady || s.suppressed) {
      // Paused by the user, or held by the system (a phone call has the
      // audio): nothing is wrong, and the clock restarts on resume.
      _movedAt = now;
      _smoothSince = null;
      _lastPosition = s.position;
      _loading = false;
      return WatchdogAction.none;
    }

    final moved = s.playing &&
        _lastPosition != null &&
        s.position != _lastPosition;
    _lastPosition = s.position;
    if (moved) {
      _movedAt = now;
      _movedSinceOpen = true;
      _smoothSince ??= now;
      final smoothFor = now.difference(_smoothSince!);
      // Before the first picture, keep the loading screen until a real frame
      // is up (hides decoder warm-up); audio-only streams count after a
      // couple of seconds of sound.
      if (_everPlayed || s.hasVideo || smoothFor >= _stableAfter) {
        _everPlayed = true;
        _loading = false;
      }
      if (smoothFor >= _stableAfter) _attempts = 0;
      return WatchdogAction.none;
    }

    final stuckFor = now.difference(_movedAt!);
    if (stuckFor >= showLoadingAfter) {
      _loading = true;
      _smoothSince = null;
    }
    if (stuckFor >= _limit) return _reconnect(now);
    return WatchdogAction.none;
  }

  /// The engine reported an error that isn't permanent: reconnect now
  /// rather than waiting for the freeze limit.
  WatchdogAction onError(DateTime now) {
    _loading = true;
    return _reconnect(now);
  }

  Duration get _limit {
    if (_movedSinceOpen) return freezeLimit;
    // Connecting. After the first few quick tries of a stream that had been
    // playing, space them out (provider outage, phone off Wi-Fi).
    if (_everPlayed && _attempts > 3) {
      final extra = Duration(seconds: 2 * (_attempts - 3));
      final limit = connectLimit + extra;
      // Never below the connect window (a bigger buffer setting needs it).
      final cap = maxBackoff > connectLimit ? maxBackoff : connectLimit;
      return limit > cap ? cap : limit;
    }
    return connectLimit;
  }

  WatchdogAction _reconnect(DateTime now) {
    if (!_everPlayed && _attempts >= maxAttemptsBeforePlaying) {
      return WatchdogAction.giveUp;
    }
    _attempts++;
    _movedAt = now;
    _reconnectedAt = now;
    _smoothSince = null;
    return WatchdogAction.reconnect;
  }
}
