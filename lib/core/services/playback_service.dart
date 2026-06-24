import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart'; // needed for VideoController GC anchor
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playback_service.g.dart';

enum StreamType { hls, mpegTs, progressive, auto }

@Riverpod(keepAlive: true)
PlaybackService playbackService(PlaybackServiceRef ref) {
  final db = ref.watch(appDatabaseProvider);
  final service = PlaybackService(db: db);
  ref.onDispose(service.dispose);
  return service;
}

class PlaybackService {
  PlaybackService({required this.db}) {
    _player = Player();
  }

  final AppDatabase db;
  late final Player _player;

  // GC anchor: keeps the active VideoController alive while mpv's native
  // opener thread may still fire Dart callbacks (Callback invoked after deleted).
  // Set by PlayerScreen.initState, cleared by PlayerScreen.dispose.
  VideoController? _activeController;
  void attachVideoController(VideoController c) => _activeController = c;
  void detachVideoController() => _activeController = null;

  Player get player => _player;

  // ---------------------------------------------------------------------------
  // Stream type detection
  // ---------------------------------------------------------------------------

  static StreamType detectStreamType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') || lower.contains('hls')) return StreamType.hls;
    if (lower.contains('.ts') || lower.contains('mpeg-ts')) {
      return StreamType.mpegTs;
    }
    if (lower.contains('.mp4') ||
        lower.contains('.mkv') ||
        lower.contains('.avi')) {
      return StreamType.progressive;
    }
    return StreamType.auto;
  }

  // ---------------------------------------------------------------------------
  // Playback control
  // ---------------------------------------------------------------------------

  Future<void> play(String streamUrl, {Duration? startPosition}) async {
    final media = Media(streamUrl);
    await _player.open(media);
    if (startPosition != null && startPosition.inSeconds > 0) {
      // Seek only once the player is actually playing; seeking right after
      // open() is silently dropped because the stream hasn't buffered yet.
      await _player.stream.playing
          .firstWhere((p) => p)
          .timeout(const Duration(seconds: 20), onTimeout: () => false);
      await _player.seek(startPosition);
    }
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  Future<void> togglePlayPause() => _player.playOrPause();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> seekRelative(Duration delta) async {
    final current = _player.state.position;
    await _player.seek(current + delta);
  }

  Future<void> stop() => _player.stop();

  // ---------------------------------------------------------------------------
  // Progress persistence (VOD)
  // ---------------------------------------------------------------------------

  Future<void> saveMovieProgress(String movieId, Duration total) async {
    final position = _player.state.position;
    if (total.inSeconds == 0) return;
    await db.updateMovieProgress(movieId, position, total);
  }

  Future<void> saveEpisodeProgress(String episodeId, Duration total) async {
    final position = _player.state.position;
    if (total.inSeconds == 0) return;
    await db.updateEpisodeProgress(episodeId, position, total);
  }

  void dispose() => _player.dispose();
}
