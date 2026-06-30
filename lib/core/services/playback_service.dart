import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
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
    final native = _player.platform;
    if (native is NativePlayer) {
      // Default CC/subtitles to off. sub-auto=no prevents mpv from auto-selecting
      // any subtitle track; sub-visibility=no hides rendering for the rare case
      // where a track is selected manually before this runs.
      native.setProperty('sub-auto', 'no');
      native.setProperty('sub-visibility', 'no');
      // Tell FFmpeg's lavf demuxer to scan all PMTs in MPEG-TS containers.
      // Required to surface CEA-608/708 CC and other tracks that live in
      // secondary programs (common in US broadcast-style IPTV streams).
      native.setProperty('demuxer-lavf-o', 'scan_all_pmts=1');
    }
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
    // Set hwdec here — after VideoController.initState() has run and may have
    // set hwdec=auto internally — so our value wins when the media opens.
    final native = _player.platform;
    if (native is NativePlayer) {
      final hwdecValue = Platform.isAndroid ? 'mediacodec-copy' : 'auto';
      await native.setProperty('hwdec', hwdecValue);
      await native.setProperty('hwdec-codecs', 'all');
      debugPrint('[OTV-hwdec] setProperty hwdec=$hwdecValue done');
    } else {
      debugPrint('[OTV-hwdec] NativePlayer not available — skipping hwdec setup');
    }
    final media = Media(streamUrl);
    debugPrint('[OTV-play] opening url=${streamUrl.split('?').first}, startPosition=${startPosition?.inSeconds}s');
    await _player.open(media);
    debugPrint('[OTV-play] open() returned, playing=${_player.state.playing}, duration=${_player.state.duration.inSeconds}s');
    if (startPosition != null && startPosition.inSeconds > 0) {
      // Wait for mpv to parse the container and populate duration before seeking.
      // 'playing=true' fires too early (before the index is ready), so a seek
      // at that point silently no-ops. Duration > 0 means the demuxer has the
      // seek table and can honor arbitrary position requests.
      final durationFuture = _player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 20), onTimeout: () => Duration.zero);
      if (_player.state.duration == Duration.zero) {
        debugPrint('[OTV-play] waiting for duration...');
        await durationFuture;
      }
      debugPrint('[OTV-play] duration=${_player.state.duration.inSeconds}s, seeking to ${startPosition.inSeconds}s');
      await _player.seek(startPosition);
      debugPrint('[OTV-play] seek() returned, state.position=${_player.state.position.inSeconds}s');
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

  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    await _player.setSubtitleTrack(track);
    // sub-visibility is decoupled from track selection — sync it explicitly.
    final native = _player.platform;
    if (native is NativePlayer) {
      await native.setProperty(
          'sub-visibility', track.id == 'no' ? 'no' : 'yes');
    }
  }

  // ---------------------------------------------------------------------------
  // Progress persistence (VOD)
  // ---------------------------------------------------------------------------

  Future<void> saveMovieProgress(
      String movieId, Duration position, Duration total) async {
    debugPrint('[OTV-save] saveMovieProgress: pos=${position.inSeconds}s total=${total.inSeconds}s');
    if (position.inSeconds == 0 || total.inSeconds == 0) {
      debugPrint('[OTV-save] skipping — position or total is 0');
      return;
    }
    await db.updateMovieProgress(movieId, position, total);
    debugPrint('[OTV-save] updateMovieProgress done');
  }

  Future<void> saveEpisodeProgress(
      String episodeId, Duration position, Duration total) async {
    debugPrint('[OTV-save] saveEpisodeProgress: pos=${position.inSeconds}s total=${total.inSeconds}s');
    if (position.inSeconds == 0 || total.inSeconds == 0) {
      debugPrint('[OTV-save] skipping — position or total is 0');
      return;
    }
    await db.updateEpisodeProgress(episodeId, position, total);
    debugPrint('[OTV-save] updateEpisodeProgress done');
  }

  void dispose() => _player.dispose();
}
