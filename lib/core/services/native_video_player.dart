import 'dart:async';

import 'package:flutter/services.dart';

/// Playback state snapshot from the native ExoPlayer engine.
class NativeVideoPlayerState {
  const NativeVideoPlayerState({
    required this.position,
    required this.duration,
    required this.playing,
    required this.buffering,
    required this.completed,
    required this.videoWidth,
    required this.videoHeight,
    this.pixelRatio = 1.0,
  });

  final Duration position;
  final Duration duration;
  final bool playing;
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

/// One audio or subtitle/CC track, as reported by ExoPlayer's track model.
class NativeVideoTrack {
  const NativeVideoTrack({
    required this.id,
    required this.type,
    required this.label,
    required this.language,
    required this.selected,
  });

  factory NativeVideoTrack.fromMap(Map<Object?, Object?> map) {
    return NativeVideoTrack(
      id: map['id'] as String,
      type: map['type'] as String,
      label: map['label'] as String,
      language: map['language'] as String?,
      selected: map['selected'] as bool,
    );
  }

  final String id;
  // 'audio' or 'text' (subtitle/CC).
  final String type;
  final String label;
  final String? language;
  final bool selected;
}

/// Dart wrapper around the native ExoPlayer-based video engine
/// (android/app/.../NativeVideoPlayer.kt), replacing media_kit/mpv.
///
/// One instance == one native texture/ExoPlayer pair. Create multiple
/// instances for concurrent playback (e.g. the TV guide's mini preview).
class NativeVideoPlayer {
  static const _control = MethodChannel('openiptv/video_player');

  int? _textureId;
  StreamSubscription<dynamic>? _eventSub;
  final _stateController =
      StreamController<NativeVideoPlayerState>.broadcast();
  final _cueController = StreamController<String>.broadcast();
  final _tracksController = StreamController<List<NativeVideoTrack>>.broadcast();

  /// The Flutter `Texture` widget's `textureId` once [create] resolves.
  int get textureId => _textureId!;
  bool get isCreated => _textureId != null;

  Stream<NativeVideoPlayerState> get stateStream => _stateController.stream;
  // Current subtitle/CC cue text — empty string means "nothing showing".
  Stream<String> get cueStream => _cueController.stream;
  Stream<List<NativeVideoTrack>> get tracksStream => _tracksController.stream;

  Future<int> create() async {
    final id = await _control.invokeMethod<int>('create');
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
        default:
          _stateController.add(NativeVideoPlayerState(
            position: Duration(milliseconds: map['position'] as int),
            duration: Duration(milliseconds: map['duration'] as int),
            playing: map['playing'] as bool,
            buffering: map['buffering'] as bool,
            completed: map['completed'] as bool? ?? false,
            videoWidth: map['videoWidth'] as int? ?? 0,
            videoHeight: map['videoHeight'] as int? ?? 0,
            pixelRatio: (map['pixelRatio'] as num?)?.toDouble() ?? 1.0,
          ));
      }
    });
    return id!;
  }

  Future<List<NativeVideoTrack>> getTracks() async {
    final result =
        await _control.invokeMethod<List<Object?>>('getTracks', {'id': _textureId});
    return (result ?? [])
        .map((t) => NativeVideoTrack.fromMap(Map<Object?, Object?>.from(t as Map)))
        .toList();
  }

  Future<void> selectTrack(String trackId) => _control.invokeMethod(
      'selectTrack', {'id': _textureId, 'trackId': trackId});

  Future<void> clearTextTrack() =>
      _control.invokeMethod('clearTextTrack', {'id': _textureId});

  Future<void> open(String url, {String? streamTypeHint}) {
    return _control.invokeMethod('open', {
      'id': _textureId,
      'url': url,
      'streamTypeHint': streamTypeHint,
    });
  }

  Future<void> play() => _control.invokeMethod('play', {'id': _textureId});
  Future<void> pause() => _control.invokeMethod('pause', {'id': _textureId});
  Future<void> stop() => _control.invokeMethod('stop', {'id': _textureId});

  // Returns the resulting position immediately (ExoPlayer updates its
  // position synchronously, unlike mpv's async position reporting).
  Future<Duration> seekTo(Duration position) async {
    final ms = await _control.invokeMethod<int>('seekTo', {
      'id': _textureId,
      'positionMs': position.inMilliseconds,
    });
    return Duration(milliseconds: ms ?? position.inMilliseconds);
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    if (_textureId != null) {
      await _control.invokeMethod('dispose', {'id': _textureId});
    }
    await _stateController.close();
    await _cueController.close();
    await _tracksController.close();
  }
}
