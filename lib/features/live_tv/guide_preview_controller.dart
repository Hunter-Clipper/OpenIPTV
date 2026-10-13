import 'package:open_iptv/core/services/native_video_player.dart';
import 'package:open_iptv/core/services/playback_service.dart';

/// The TV guide's preview player: its own native player, separate from the
/// app's main one (which the full-screen player owns). Only ever plays
/// because you asked (OK on a channel), so it has the sound. Dispose it to
/// free its stream before anything else plays — some plans allow a single
/// connection.
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
  bool _disposed = false;

  /// Null until the native texture is ready.
  int? get textureId => _ready ? _player.textureId : null;

  Stream<NativeVideoPlayerState> get stateStream => _player.stateStream;

  Future<void> play(String streamUrl) async {
    await _createFuture;
    if (_disposed) return;
    await _player.open(streamUrl,
        streamTypeHint: PlaybackService.streamTypeHint(streamUrl));
    await _player.play();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // After create() has finished, or the native player would be left
    // behind.
    _createFuture.then((_) => _player.dispose(), onError: (_) {});
  }
}
