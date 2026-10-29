// Native-only stand-in for the web video engine. Imported (instead of
// web_player_impl.dart) whenever dart:html is unavailable, i.e. on native.
// Its members are never called — the player only touches them under `kIsWeb`
// — they just have to exist so native_video_player.dart compiles on Android.
import 'dart:async';

class WebTrack {
  WebTrack({
    required this.id,
    required this.type,
    required this.label,
    this.language,
    required this.selected,
    this.mimeType,
    this.channel = -1,
  });
  final String id;
  final String type;
  final String label;
  final String? language;
  final bool selected;
  final String? mimeType;
  final int channel;
}

class WebSnapshot {
  WebSnapshot({
    required this.position,
    required this.duration,
    required this.playing,
    required this.buffering,
    required this.completed,
    required this.videoWidth,
    required this.videoHeight,
  });
  final double position;
  final double duration;
  final bool playing;
  final bool buffering;
  final bool completed;
  final int videoWidth;
  final int videoHeight;
}

class WebPlaybackEngine {
  WebPlaybackEngine({required void Function(WebSnapshot) onState}) {
    throw UnsupportedError('WebPlaybackEngine is web-only');
  }

  String get viewType => throw UnsupportedError('WebPlaybackEngine is web-only');
  int get webId => -1;

  Future<void> open(String url,
          {String? streamTypeHint,
          bool audioFocus = true,
          Duration? startPosition}) =>
      throw UnsupportedError('WebPlaybackEngine is web-only');
  void play() => throw UnsupportedError('WebPlaybackEngine is web-only');
  void pause() => throw UnsupportedError('WebPlaybackEngine is web-only');
  Future<void> seekTo(double seconds) =>
      throw UnsupportedError('WebPlaybackEngine is web-only');
  void setSpeed(double speed) => throw UnsupportedError('web-only');
  void setAudible(bool on) => throw UnsupportedError('WebPlaybackEngine is web-only');
  bool get isLive => throw UnsupportedError('WebPlaybackEngine is web-only');
  List<WebTrack> tracks() => throw UnsupportedError('WebPlaybackEngine is web-only');
  Future<void> dispose() => throw UnsupportedError('WebPlaybackEngine is web-only');
}
