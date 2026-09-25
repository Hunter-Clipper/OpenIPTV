import 'package:open_iptv/core/services/native_video_player.dart';
import 'package:open_iptv/core/services/playback_service.dart';

/// Owns a small, independent native ExoPlayer instance for the TV guide's
/// mini live-preview panel — deliberately separate from the app's main
/// PlaybackService engine (which PlayerScreen owns), since this is a second
/// concurrent decoder scoped only to the guide screen's lifetime. No
/// DVR/catch-up/resume logic here, just "open whatever channel is currently
/// focused."
class GuidePreviewController {
  GuidePreviewController() {
    _createFuture = _player.create().then((id) {
      _ready = true;
      return id;
    });
  }

  final NativeVideoPlayer _player = NativeVideoPlayer();
  late final Future<int> _createFuture;
  bool _ready = false;
  String? _currentUrl;

  /// Null until the native texture is ready.
  int? get textureId => _ready ? _player.textureId : null;

  Stream<NativeVideoPlayerState> get stateStream => _player.stateStream;

  Future<void> tune(String streamUrl) async {
    await _createFuture;
    if (streamUrl == _currentUrl) return;
    _currentUrl = streamUrl;
    final hint = PlaybackService.detectStreamType(streamUrl) == StreamType.hls
        ? 'hls'
        : 'ts';
    await _player.open(streamUrl, streamTypeHint: hint);
    await _player.play();
  }

  Future<void> pause() => _player.pause();

  void dispose() => _player.dispose();
}
