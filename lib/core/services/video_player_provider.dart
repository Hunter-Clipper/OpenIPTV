import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'native_video_player.dart';
import 'video_player_base.dart';
import 'web_video_player.dart';

/// Provides the platform-appropriate [VideoPlayer] implementation.
final videoPlayerProvider = Provider<VideoPlayer>((ref) {
  if (kIsWeb) {
    return WebVideoPlayer();
  }
  // Default to Android for now. Future: add Windows/iOS.
  return AndroidVideoPlayer();
});
