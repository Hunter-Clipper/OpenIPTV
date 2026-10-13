import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:open_iptv/core/services/buffer_preset.dart';
import 'package:open_iptv/core/services/native_video_player.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/utils/redact.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'playback_service.g.dart';

enum StreamType { hls, mpegTs, progressive, auto }

@Riverpod(keepAlive: true)
PlaybackService playbackService(PlaybackServiceRef ref) {
  final db = ref.watch(appDatabaseProvider);
  final service = PlaybackService(
    db: db,
    bufferPreset: () => BufferPreset.fromId(
        ref.read(appPreferencesProvider).valueOrNull?.bufferPreset),
  );
  ref.onDispose(service.dispose);
  return service;
}

class PlaybackService {
  PlaybackService({required this.db, BufferPreset Function()? bufferPreset})
      : _bufferPreset = bufferPreset ?? (() => BufferPreset.fast) {
    _stateSub = _player.stateStream.listen((s) => _lastState = s);
  }

  final AppDatabase db;
  final BufferPreset Function() _bufferPreset;

  /// The buffer setting new streams open with (Power User Tools).
  BufferPreset get bufferPreset => _bufferPreset();
  final NativeVideoPlayer _player = NativeVideoPlayer();
  late final StreamSubscription<NativeVideoPlayerState> _stateSub;
  NativeVideoPlayerState _lastState = const NativeVideoPlayerState(
    position: Duration.zero,
    duration: Duration.zero,
    playing: false,
    buffering: false,
    completed: false,
    videoWidth: 0,
    videoHeight: 0,
  );
  Future<int>? _createFuture;

  /// Bumped on every [play] — lets the stream watchdog tell a fresh
  /// connection (still connecting) from one that has been playing.
  int get openCount => _openCount;
  int _openCount = 0;

  // One ExoPlayer instance lives for the whole app session (same lifetime
  // media_kit's single global Player had) — this creates its texture once,
  // on first use, and every later play() just reuses it.
  Future<int> ensureTexture() => _createFuture ??= _player.create();

  bool get hasTexture => _player.isCreated;
  int get textureId => _player.textureId;

  NativeVideoPlayerState get lastState => _lastState;
  Stream<NativeVideoPlayerState> get stateStream => _player.stateStream;
  Stream<String> get cueStream => _player.cueStream;
  Stream<NativePlaybackError> get errorStream => _player.errorStream;
  Stream<List<NativeVideoTrack>> get tracksStream => _player.tracksStream;

  // Set by a caller (e.g. the EPG panel) right before it replaces the
  // current PlayerScreen with a new one on the same shared engine — such as
  // switching from live to catch-up. The outgoing PlayerScreen has no way to
  // know its dispose() was triggered by a deliberate hand-off rather than a
  // real exit, since pushReplacement is called from outside its own state.
  // Its dispose() consumes this flag to skip stop()/orientation-reset, which
  // would otherwise kill the incoming screen's just-started playback.
  bool _transitioning = false;
  void markTransitioning() => _transitioning = true;
  bool consumeTransitioning() {
    final v = _transitioning;
    _transitioning = false;
    return v;
  }

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

  /// The extractor hint for [url]'s native `open()`: null lets ExoPlayer
  /// pick.
  static String? streamTypeHint(String url) {
    switch (detectStreamType(url)) {
      case StreamType.hls:
        return 'hls';
      case StreamType.mpegTs:
        return 'ts';
      case StreamType.progressive:
      case StreamType.auto:
        // Let the native side use ExoPlayer's default extractors — the
        // CC-aware custom TsExtractor path is for raw MPEG-TS (live/catch-up)
        // only; forcing it on VOD containers like mp4/mkv silently stalls
        // playback forever (TsExtractor never finds valid TS sync bytes in
        // an mp4 file, so ExoPlayer just sits in BUFFERING with no samples).
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Playback control
  // ---------------------------------------------------------------------------

  /// Who opened the current stream (a player screen, Android Auto…). Lets
  /// a player screen notice that something else took over the shared
  /// player, and stop managing it (#41 car bug: the phone's screen kept
  /// "reconnecting" to its own channel over what the car had picked).
  Object? get owner => _owner;
  Object? _owner;

  /// What the shared player has open, and for whom (null once stopped). The
  /// TV guide's preview pane follows it.
  final nowPlaying = ValueNotifier<({String url, Object? owner})?>(null);

  /// [owner] carries on with what's already playing — no reopening (the
  /// TV guide's preview going full screen, and back).
  void adopt(Object owner) {
    final current = nowPlaying.value;
    if (current == null) return;
    _owner = owner;
    nowPlaying.value = (url: current.url, owner: owner);
  }

  /// [carScreen]: started from Android Auto, so the picture may go to the
  /// car screen (the "OpenIPTV Video" add-on); otherwise it stays here.
  Future<void> play(String streamUrl,
      {Duration? startPosition, Object? owner, bool carScreen = false}) async {
    _owner = owner;
    nowPlaying.value = (url: streamUrl, owner: owner);
    await ensureTexture();
    debugPrint('[OTV-play] opening url=${redactUrl(streamUrl.split('?').first)}, '
        'startPosition=${startPosition?.inSeconds}s');
    // ExoPlayer starts at startPosition itself — no need to wait for the
    // duration and seek afterwards (an mpv-era workaround that briefly
    // played from 0 before jumping).
    _speed = 1;
    _openCount++;
    await _player.open(streamUrl,
        streamTypeHint: streamTypeHint(streamUrl),
        startPosition: startPosition,
        bufferPreset: bufferPreset.id,
        carScreen: carScreen);
    await _player.play();
    debugPrint('[OTV-play] open()/play() done');
  }

  Future<void> pause() => _player.pause();
  Future<void> resume() => _player.play();
  // Follows what the user asked for, not whether frames are moving: tapping
  // during a stall pauses rather than "resuming" an already-playing stream.
  Future<void> togglePlayPause() =>
      _lastState.playWhenReady ? pause() : resume();

  Future<void> seek(Duration position) => _player.seekTo(position);

  Future<void> seekRelative(Duration delta) async {
    final target = _lastState.position + delta;
    debugPrint('[OTV-seek] seekRelative: delta=${delta.inSeconds}s '
        'target=${target.inSeconds}s');
    await _player.seekTo(target);
  }

  Future<void> stop() {
    nowPlaying.value = null;
    return _player.stop();
  }

  /// Multi-view: mutes the main player (and gives up audio focus) while
  /// another tile is the one you hear.
  Future<void> setAudible(bool on) => _player.setAudible(on);

  /// Playback speed of the current stream; reset to 1 by every [play].
  double get speed => _speed;
  double _speed = 1;
  Future<void> setSpeed(double speed) {
    _speed = speed;
    return _player.setSpeed(speed);
  }

  Future<void> selectTrack(String trackId) => _player.selectTrack(trackId);
  Future<void> clearTextTrack() => _player.clearTextTrack();
  Future<List<NativeVideoTrack>> getTracks() => _player.getTracks();

  // ---------------------------------------------------------------------------
  // Progress persistence (VOD)
  // ---------------------------------------------------------------------------

  Future<void> saveMovieProgress(
      String profileId, String movieId, Duration position, Duration total) async {
    debugPrint('[OTV-save] saveMovieProgress: pos=${position.inSeconds}s total=${total.inSeconds}s');
    if (position.inSeconds == 0 || total.inSeconds == 0) {
      debugPrint('[OTV-save] skipping — position or total is 0');
      return;
    }
    await db.updateMovieProgress(profileId, movieId, position, total);
    debugPrint('[OTV-save] updateMovieProgress done');
  }

  Future<void> saveEpisodeProgress(
      String profileId, String episodeId, Duration position, Duration total) async {
    debugPrint('[OTV-save] saveEpisodeProgress: pos=${position.inSeconds}s total=${total.inSeconds}s');
    if (position.inSeconds == 0 || total.inSeconds == 0) {
      debugPrint('[OTV-save] skipping — position or total is 0');
      return;
    }
    await db.updateEpisodeProgress(profileId, episodeId, position, total);
    debugPrint('[OTV-save] updateEpisodeProgress done');
  }

  void dispose() {
    _stateSub.cancel();
    _player.dispose();
  }
}
