import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Owns a small, independent media_kit Player for the TV guide's mini
/// live-preview panel — deliberately separate from the app's main
/// PlaybackService/Player singleton (which PlayerScreen owns), since this is
/// a second concurrent decoder scoped only to the guide screen's lifetime.
/// No DVR/catch-up/resume logic here, just "open whatever channel is
/// currently focused."
class GuidePreviewController {
  GuidePreviewController() {
    _player = Player();
    final native = _player.platform;
    if (native is NativePlayer) {
      // Same subtitle-suppression defaults as the main PlaybackService —
      // this preview never shows CC/subtitles.
      native.setProperty('sub-auto', 'no');
      native.setProperty('sid', 'no');
      native.setProperty('sub-visibility', 'no');
    }
    controller = VideoController(_player);
  }

  late final Player _player;
  late final VideoController controller;
  String? _currentUrl;

  Future<void> tune(String streamUrl) async {
    if (streamUrl == _currentUrl) return;
    _currentUrl = streamUrl;
    await _player.open(Media(streamUrl));
  }

  Future<void> pause() => _player.pause();

  void dispose() => _player.dispose();
}
