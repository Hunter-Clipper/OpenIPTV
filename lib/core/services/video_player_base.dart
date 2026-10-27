import 'dart:async';

/// Playback state snapshot from the video engine.
class VideoPlayerState {
  const VideoPlayerState({
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
  // First real decoded frame's size — 0 until one has actually rendered.
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

/// A playback failure reported by the video engine.
class VideoPlaybackError {
  const VideoPlaybackError({required this.code, this.httpStatus});

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

/// One audio or subtitle/CC track.
class VideoTrack {
  const VideoTrack({
    required this.id,
    required this.type,
    required this.label,
    required this.language,
    required this.selected,
    this.mimeType,
    this.channel = -1,
  });

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

/// Abstract interface for a video player instance.
abstract class VideoPlayer {
  int? get textureId;
  bool get isCreated => textureId != null;

  Stream<VideoPlayerState> get stateStream;
  Stream<String> get cueStream;
  Stream<VideoPlaybackError> get errorStream;
  Stream<List<VideoTrack>> get tracksStream;

  Future<int> create({bool audioFocus = true});
  Future<List<VideoTrack>> getTracks();
  Future<void> selectTrack(String trackId);
  Future<void> clearTextTrack();
  Future<void> open(
    String url, {
    String? streamTypeHint,
    Duration? startPosition,
    String bufferPreset = 'fast',
    bool carScreen = false,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> setAudible(bool on);
  Future<void> setSpeed(double speed);
  Future<Duration> seekTo(Duration position);
  Future<void> dispose();
}
