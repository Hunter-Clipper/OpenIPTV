import 'dart:async';
import 'video_player_base.dart';

/// A stub implementation of [VideoPlayer] for the Web.
/// Real implementation will likely use the `video_player` plugin or `media_kit`.
class WebVideoPlayer implements VideoPlayer {
  int? _textureId;

  @override
  int get textureId => _textureId ?? -1;

  final _stateController = StreamController<VideoPlayerState>.broadcast();
  final _cueController = StreamController<String>.broadcast();
  final _errorController = StreamController<VideoPlaybackError>.broadcast();
  final _tracksController = StreamController<List<VideoTrack>>.broadcast();

  @override
  Stream<VideoPlayerState> get stateStream => _stateController.stream;
  @override
  Stream<String> get cueStream => _cueController.stream;
  @override
  Stream<VideoPlaybackError> get errorStream => _errorController.stream;
  @override
  Stream<List<VideoTrack>> get tracksStream => _tracksController.stream;

  @override
  Future<int> create({bool audioFocus = true}) async {
    _textureId = 0; // Web doesn't use native textures in the same way.
    return _textureId!;
  }

  @override
  Future<List<VideoTrack>> getTracks() async => [];

  @override
  Future<void> selectTrack(String trackId) async {}

  @override
  Future<void> clearTextTrack() async {}

  @override
  Future<void> open(
    String url, {
    String? streamTypeHint,
    Duration? startPosition,
    String bufferPreset = 'fast',
    bool carScreen = false,
  }) async {
    // Stub: Emit a buffering state then an error or a fake playing state.
    _stateController.add(VideoPlayerState(
      position: Duration.zero,
      duration: Duration.zero,
      playing: false,
      buffering: true,
      completed: false,
      videoWidth: 0,
      videoHeight: 0,
    ));
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setAudible(bool on) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<Duration> seekTo(Duration position) async => position;

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _cueController.close();
    await _errorController.close();
    await _tracksController.close();
  }
}
