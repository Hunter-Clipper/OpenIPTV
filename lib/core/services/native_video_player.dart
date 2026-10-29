import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'web_player_stub.dart' if (dart.library.html) 'web_player_impl.dart' as web;

/// Playback state snapshot from the video engine (native ExoPlayer or the web
/// <video> element). One type for both, so the UI never branches on platform.
class NativeVideoPlayerState {
  const NativeVideoPlayerState({
    required this.position,
    required this.duration,
    required this.playing,
    this.playWhenReady = false,
    this.suppressed = false,
    required this.buffering,
    required this.completed,
    required this.videoWidth,
    required this.videoHeight,
    this.pixelRatio = 1.0,
  });

  final Duration position;
  final Duration duration;
  /// Frames are actually moving (false while paused *or* stalled).
  final bool playing;

  /// The player is meant to be playing — false only when paused. Together
  /// with [playing] this tells a freeze from a pause.
  final bool playWhenReady;

  /// Held back by the system although [playWhenReady] (e.g. a phone call
  /// took audio focus). Not a stall.
  final bool suppressed;
  final bool buffering;
  final bool completed;
  // First real decoded frame's size — 0 until one has actually rendered,
  // the same "definitely not just blocky decoder warmup" signal
  // media_kit's videoParams.w>0 gave the buffering overlay.
  final int videoWidth;
  final int videoHeight;
  // Pixel width/height ratio; 1.0 except for anamorphic content.
  final double pixelRatio;

  bool get hasVideo => videoWidth > 0;

  /// Display aspect ratio of the content, or null until the first frame.
  double? get aspectRatio => videoWidth > 0 && videoHeight > 0
      ? videoWidth * pixelRatio / videoHeight
      : null;
}

/// A playback failure reported by the engine.
class NativePlaybackError {
  const NativePlaybackError({required this.code, this.httpStatus});

  // ExoPlayer PlaybackException error-code name, e.g. ERROR_CODE_IO_BAD_HTTP_STATUS.
  final String code;
  // Set when the server answered with an HTTP error status.
  final int? httpStatus;

  /// The server says this stream doesn't exist or isn't allowed — retrying
  /// won't help.
  bool get isPermanent =>
      httpStatus == 401 ||
      httpStatus == 403 ||
      httpStatus == 404 ||
      httpStatus == 410;
}

/// One audio or subtitle/CC track, as reported by the engine's track model.
class NativeVideoTrack {
  const NativeVideoTrack({
    required this.id,
    required this.type,
    required this.label,
    required this.language,
    required this.selected,
    this.mimeType,
    this.channel = -1,
  });

  factory NativeVideoTrack.fromMap(Map<Object?, Object?> map) {
    return NativeVideoTrack(
      id: map['id'] as String,
      type: map['type'] as String,
      label: map['label'] as String,
      language: map['language'] as String?,
      selected: map['selected'] as bool,
      mimeType: map['mimeType'] as String?,
      channel: map['channel'] as int? ?? -1,
    );
  }

  final String id;
  // 'audio' or 'text' (subtitle/CC).
  final String type;
  final String label;
  final String? language;
  final bool selected;
  // e.g. 'application/cea-608'; null if unknown.
  final String? mimeType;
  // CEA-608/708 caption channel/service number, or -1.
  final int channel;
}

/// Dart wrapper around the video engine. On Android it talks to the native
/// ExoPlayer-based player (android/app/.../NativeVideoPlayer.kt) over a
/// platform channel; on the web it drives an HTML <video> element through
/// hls.js / mpegts.js. The public API is identical either way.
///
/// One instance == one engine/texture pair. Create multiple instances for
/// concurrent playback (e.g. the TV guide's mini preview).
class NativeVideoPlayer {
  static const _control = MethodChannel('openiptv/video_player');

  int? _textureId;
  StreamSubscription<dynamic>? _eventSub;
  web.WebPlaybackEngine? _web;
  final _stateController =
      StreamController<NativeVideoPlayerState>.broadcast();
  final _cueController = StreamController<String>.broadcast();
  final _errorController =
      StreamController<NativePlaybackError>.broadcast();
  final _tracksController =
      StreamController<List<NativeVideoTrack>>.broadcast();

  /// The Flutter `Texture` widget's `textureId` once [create] resolves (an
  /// integer view id on web, reused to address the HTML video surface).
  int get textureId => _textureId!;
  bool get isCreated => _textureId != null;

  Stream<NativeVideoPlayerState> get stateStream => _stateController.stream;
  // Current subtitle/CC cue text — empty string means "nothing showing".
  Stream<String> get cueStream => _cueController.stream;
  Stream<NativePlaybackError> get errorStream => _errorController.stream;
  Stream<List<NativeVideoTrack>> get tracksStream => _tracksController.stream;

  /// [audioFocus]: this player is the app's media audio (holds focus, so
  /// Android Auto routes it to the car). False for silent previews.
  Future<int> create({bool audioFocus = true}) async {
    if (kIsWeb) {
      _web = web.WebPlaybackEngine(onState: _onWebState);
      _textureId = _web!.webId;
      return _textureId!;
    }
    final id = await _control
        .invokeMethod<int>('create', {'audioFocus': audioFocus});
    _textureId = id;
    final events = EventChannel('openiptv/video_player_events/$id');
    _eventSub = events.receiveBroadcastStream().listen((event) {
      final map = Map<Object?, Object?>.from(event as Map);
      switch (map['type']) {
        case 'cues':
          _cueController.add(map['text'] as String? ?? '');
        case 'tracks':
          final list = (map['tracks'] as List)
              .map((t) => NativeVideoTrack.fromMap(
                  Map<Object?, Object?>.from(t as Map)))
              .toList();
          _tracksController.add(list);
        case 'error':
          _errorController.add(NativePlaybackError(
            code: map['code'] as String? ?? 'unknown',
            httpStatus: map['httpStatus'] as int?,
          ));
        default:
          _pushState(
            position: (map['position'] as int).toDouble(),
            duration: (map['duration'] as int).toDouble(),
            playing: map['playing'] as bool,
            playWhenReady: map['playWhenReady'] as bool? ?? false,
            suppressed: map['suppressed'] as bool? ?? false,
            buffering: map['buffering'] as bool,
            completed: map['completed'] as bool? ?? false,
            videoWidth: (map['videoWidth'] as int?) ?? 0,
            videoHeight: (map['videoHeight'] as int?) ?? 0,
            pixelRatio: (map['pixelRatio'] as num?)?.toDouble() ?? 1.0,
          );
      }
    });
    return id!;
  }

  // Maps the web engine's snapshot onto the shared state type. The engine
  // reports seconds; the state (like the native player) is in milliseconds.
  void _onWebState(web.WebSnapshot s) {
    _pushState(
      position: s.position * 1000,
      duration: s.duration * 1000,
      playing: s.playing,
      buffering: s.buffering,
      completed: s.completed,
      videoWidth: s.videoWidth,
      videoHeight: s.videoHeight,
    );
  }

  void _pushState({
    required double position,
    required double duration,
    required bool playing,
    bool playWhenReady = true,
    bool suppressed = false,
    required bool buffering,
    required bool completed,
    required int videoWidth,
    required int videoHeight,
    double pixelRatio = 1.0,
  }) {
    if (_stateController.isClosed) return;
    _stateController.add(NativeVideoPlayerState(
      position: Duration(milliseconds: position.round()),
      duration: Duration(milliseconds: duration.round()),
      playing: playing,
      playWhenReady: playWhenReady,
      suppressed: suppressed,
      buffering: buffering,
      completed: completed,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      pixelRatio: pixelRatio,
    ));
  }

  Future<List<NativeVideoTrack>> getTracks() async {
    if (kIsWeb) {
      return _web!.tracks().map((t) => NativeVideoTrack(
            id: t.id,
            type: t.type,
            label: t.label,
            language: t.language,
            selected: t.selected,
            mimeType: t.mimeType,
            channel: t.channel,
          )).toList();
    }
    final result =
        await _control.invokeMethod<List<Object?>>('getTracks', {'id': _textureId});
    return (result ?? [])
        .map((t) => NativeVideoTrack.fromMap(Map<Object?, Object?>.from(t as Map)))
        .toList();
  }

  Future<void> selectTrack(String trackId) async {
    if (kIsWeb) return; // hls.js selection wired later; no-op for now.
    await _control.invokeMethod(
        'selectTrack', {'id': _textureId, 'trackId': trackId});
  }

  Future<void> clearTextTrack() async {
    if (kIsWeb) return; // subtitle display toggled via tracks later; no-op now.
    await _control.invokeMethod('clearTextTrack', {'id': _textureId});
  }

  /// [bufferPreset]: a buffer id; the native player rebuilds its buffer
  /// settings when it changes (web ignores it — the browser buffers natively).
  Future<void> open(String url,
      {String? streamTypeHint,
      Duration? startPosition,
      String bufferPreset = 'fast',
      bool carScreen = false}) {
    if (kIsWeb) {
      return _web!
          .open(url, streamTypeHint: streamTypeHint, audioFocus: !carScreen);
    }
    return _control.invokeMethod('open', {
      'id': _textureId,
      'url': url,
      'streamTypeHint': streamTypeHint,
      'startPositionMs': startPosition?.inMilliseconds ?? 0,
      'bufferPreset': bufferPreset,
      'carScreen': carScreen,
    });
  }

  Future<void> play() async {
    if (kIsWeb) {
      _web!.play();
      return;
    }
    await _control.invokeMethod('play', {'id': _textureId});
  }

  /// Whether this is the player you hear: full volume and media audio
  /// focus, or muted without focus (multi-view's other tiles).
  Future<void> setAudible(bool on) async {
    if (kIsWeb) {
      _web!.setAudible(on);
      return;
    }
    await _control.invokeMethod('setAudible', {'id': _textureId, 'on': on});
  }

  Future<void> setSpeed(double speed) async {
    if (kIsWeb) {
      _web!.setSpeed(speed);
      return;
    }
    await _control.invokeMethod('setSpeed', {'id': _textureId, 'speed': speed});
  }

  Future<void> pause() async {
    if (kIsWeb) {
      _web!.pause();
      return;
    }
    await _control.invokeMethod('pause', {'id': _textureId});
  }

  Future<void> stop() async {
    if (kIsWeb) {
      _web!.pause();
      return;
    }
    await _control.invokeMethod('stop', {'id': _textureId});
  }

  // Returns the resulting position immediately (ExoPlayer updates its
  // position synchronously, unlike mpv's async position reporting).
  Future<Duration> seekTo(Duration position) async {
    if (kIsWeb) {
      await _web!.seekTo(position.inMilliseconds / 1000.0);
      return position;
    }
    final ms = await _control.invokeMethod<int>('seekTo', {
      'id': _textureId,
      'positionMs': position.inMilliseconds,
    });
    return Duration(milliseconds: ms ?? position.inMilliseconds);
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    if (kIsWeb) {
      await _web?.dispose();
      _web = null;
    } else if (_textureId != null) {
      await _control.invokeMethod('dispose', {'id': _textureId});
    }
    await _stateController.close();
    await _cueController.close();
    await _errorController.close();
    await _tracksController.close();
  }
}
