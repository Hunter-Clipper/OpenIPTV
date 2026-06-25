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
      // Subscribe to the stream BEFORE checking state so we don't miss the
      // event in the gap between the check and the subscription (Dart is
      // single-threaded, so no event fires between these two synchronous lines).
      final playFuture = _player.stream.playing
          .firstWhere((p) => p)
          .timeout(const Duration(seconds: 15), onTimeout: () => false);
      // If playing is already true (fired before we could subscribe above),
      // skip the wait — seek immediately.
      if (!_player.state.playing) {
        await playFuture;
      }
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
    // Guard on position, not total — many IPTV streams are TS-over-HTTP and
    // mpv never resolves a duration, so total stays 0. We still want to save
    // the watched position so the Resume button appears.
    if (position.inSeconds == 0) return;
    await db.updateMovieProgress(movieId, position, total);
  }

  Future<void> saveEpisodeProgress(String episodeId, Duration total) async {
    final position = _player.state.position;
    if (position.inSeconds == 0) return;
    await db.updateEpisodeProgress(episodeId, position, total);
  }

  void dispose() => _player.dispose();
}
