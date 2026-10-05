import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:open_iptv/core/services/car_library.dart';
import 'package:open_iptv/core/services/playback_service.dart';

late final NowPlayingHandler nowPlayingHandler;

/// Initializes audio_service and binds it to the app's single [PlaybackService]
/// player instance. Must be called once, before `runApp`, with the same
/// [PlaybackService] the rest of the app reads via Riverpod — otherwise the
/// notification would mirror a different, unused Player.
Future<void> initNowPlayingService(PlaybackService playbackService) async {
  nowPlayingHandler = await AudioService.init(
    builder: () => NowPlayingHandler(playbackService),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.openiptv.app.now_playing',
      androidNotificationChannelName: 'Now Playing',
      androidNotificationIcon: 'drawable/ic_stat_open_iptv',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      // Android Auto (#33): the browse tree supports search, and lists /
      // grids are styled per item (see CarLibrary).
      androidBrowsableRootExtras: {
        AndroidContentStyle.supportedKey: true,
        'android.media.browse.SEARCH_SUPPORTED': true,
      },
    ),
  );
}

/// Mirrors [PlaybackService]'s native engine state into a system media
/// notification with transport controls (play/pause/stop), so users can see
/// and control what's playing from the notification shade or lock screen.
///
/// [setEnabled] gates every visible side effect — the underlying player state
/// stream listener runs for the app's whole lifetime, so without this check
/// the notification would keep reappearing on every play/pause change
/// regardless of the user's "Media Notification" setting.
class NowPlayingHandler extends BaseAudioHandler {
  NowPlayingHandler(this._playbackService) {
    _playbackService.stateStream.listen((_) => _broadcastState());
  }

  final PlaybackService _playbackService;

  /// Android Auto's browse tree; set once the app's data layer is up.
  CarLibrary? library;

  /// Profile id for saving progress of things started in the car.
  Future<String?> Function()? currentProfileId;

  // What the car is playing (null when playback came from the phone UI),
  // and the list it was picked from — next / previous move through it.
  CarPlayable? _carItem;
  List<String> _carQueue = const [];
  Timer? _carProgressTimer;

  bool _enabled = true;
  // Starts true (nothing playing yet). Guards against the player's state
  // stream re-pushing a non-idle PlaybackState after stop() — its
  // playing/buffering updates can arrive after our idle state, which would
  // otherwise leave the notification stuck instead of torn down. Cleared by
  // setNowPlaying(), set by stop().
  bool _stopped = true;
  MediaItem? _lastMediaItem;

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      mediaItem.add(null);
      playbackState.add(PlaybackState(
        controls: const [],
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
    } else if (_lastMediaItem != null && !_stopped) {
      mediaItem.add(_lastMediaItem);
      _broadcastState();
    }
  }

  void setNowPlaying(String title, {String? artist, Uri? artUri}) {
    // The phone's player took over: the car session's queue no longer applies.
    _endCarSession();
    _stopped = false;
    final duration = _playbackService.lastState.duration;
    final item = MediaItem(
      id: title,
      title: title,
      artist: artist,
      artUri: artUri,
      duration: duration == Duration.zero ? null : duration,
    );
    _lastMediaItem = item;
    if (!_enabled) return;
    mediaItem.add(item);
    _broadcastState();
  }

  void clearNowPlaying() {
    _lastMediaItem = null;
    mediaItem.add(null);
  }

  void _broadcastState() {
    if (!_enabled || _stopped) return;
    final state = _playbackService.lastState;
    // A movie / episode's length is only known once it starts playing:
    // update the item so the car shows the real total time.
    final item = _lastMediaItem;
    if (_carItem != null &&
        !_carItem!.isLive &&
        item != null &&
        item.duration == null &&
        state.duration > Duration.zero) {
      _lastMediaItem = item.copyWith(duration: state.duration);
      mediaItem.add(_lastMediaItem);
    }
    final hasQueue = _carItem != null && _carQueue.length > 1;
    final seekable = _carItem == null || !_carItem!.isLive;
    playbackState.add(PlaybackState(
      controls: [
        if (hasQueue) MediaControl.skipToPrevious,
        state.playWhenReady ? MediaControl.pause : MediaControl.play,
        if (hasQueue) MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: {
        if (seekable) MediaAction.seek,
        // Picking or searching in Android Auto while something plays.
        MediaAction.playFromMediaId,
        MediaAction.playFromSearch,
      },
      androidCompactActionIndices: hasQueue ? const [0, 1, 2] : const [0, 1],
      playing: state.playWhenReady,
      processingState: state.buffering
          ? AudioProcessingState.buffering
          : AudioProcessingState.ready,
      // Live TV has no timeline: -1 is Android's "position unknown", so
      // the car and lock screen don't show a running clock.
      updatePosition: seekable ? state.position : const Duration(milliseconds: -1),
    ));
  }

  @override
  Future<void> play() => _playbackService.resume();

  @override
  Future<void> pause() async {
    await _playbackService.pause();
    unawaited(_saveCarProgress());
  }

  @override
  Future<void> seek(Duration position) => _playbackService.seek(position);

  @override
  Future<void> stop() async {
    await _saveCarProgress();
    _endCarSession();
    _stopped = true;
    await _playbackService.stop();
    mediaItem.add(null);
    // audio_service only tears down the foreground notification once it
    // observes a transition to AudioProcessingState.idle — _broadcastState()
    // is now a no-op (guarded by _stopped), so that transition must be
    // pushed explicitly here rather than relying on the player's streams.
    playbackState.add(PlaybackState(
      controls: const [],
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await super.stop();
  }

  // ---------------------------------------------------------------------------
  // Android Auto (#33)
  // ---------------------------------------------------------------------------

  // The children last listed per folder, so a pick knows its neighbours.
  final Map<String, List<String>> _listed = {};

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
      [Map<String, dynamic>? options]) async {
    final lib = library;
    if (lib == null) return const [];
    try {
      final items = await lib.children(parentMediaId);
      _listed[parentMediaId] = [
        for (final i in items)
          if (i.playable ?? false) i.id,
      ];
      return items;
    } catch (e) {
      debugPrint('[OTV-auto] browse $parentMediaId failed: $e');
      return const [];
    }
  }

  @override
  Future<MediaItem?> getMediaItem(String mediaId) async {
    final p = await library?.resolve(mediaId);
    return p == null ? null : _toItem(p);
  }

  @override
  Future<List<MediaItem>> search(String query,
      [Map<String, dynamic>? extras]) async {
    final items = await library?.search(query) ?? const <MediaItem>[];
    _listed['search'] = [
      for (final i in items)
        if (i.playable ?? false) i.id,
    ];
    return items;
  }

  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    final queue = _listed.values
        .firstWhere((ids) => ids.contains(mediaId), orElse: () => [mediaId]);
    await _playCar(mediaId, queue);
  }

  @override
  Future<void> playFromSearch(String query,
      [Map<String, dynamic>? extras]) async {
    final results = await search(query);
    final first = results.where((i) => i.playable ?? false).firstOrNull;
    if (first != null) await _playCar(first.id, _listed['search']!);
  }

  @override
  Future<void> skipToNext() => _skip(1);

  @override
  Future<void> skipToPrevious() => _skip(-1);

  Future<void> _skip(int delta) async {
    final current = _carItem;
    if (current == null || _carQueue.length < 2) return;
    final i = _carQueue.indexOf(current.mediaId);
    final next = _carQueue[
        ((i + delta) % _carQueue.length + _carQueue.length) %
            _carQueue.length];
    await _playCar(next, _carQueue);
  }

  Future<void> _playCar(String mediaId, List<String> queue) async {
    final p = await library?.resolve(mediaId);
    if (p == null) return;
    await _saveCarProgress();
    _carProgressTimer?.cancel();
    _carItem = p;
    _carQueue = queue;
    _stopped = false;
    final item = _toItem(p);
    _lastMediaItem = item;
    if (_enabled) mediaItem.add(item);
    debugPrint('[OTV-auto] play ${p.kind} ${p.contentId}');
    await _playbackService.play(p.streamUrl, startPosition: p.resumeAt);
    _broadcastState();
    final profileId = await currentProfileId?.call();
    if (profileId != null && p.isLive) {
      unawaited(_playbackService.db.updateChannelLastWatched(profileId, p.contentId));
    }
    if (!p.isLive) {
      // Keep Continue Watching current, like the phone's player does.
      _carProgressTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _saveCarProgress());
    }
  }

  Future<void> _saveCarProgress() async {
    final p = _carItem;
    if (p == null || p.isLive) return;
    final state = _playbackService.lastState;
    if (state.position <= Duration.zero || state.duration <= Duration.zero) {
      return;
    }
    final profileId = await currentProfileId?.call();
    if (profileId == null) return;
    try {
      if (p.kind == 'movie') {
        await _playbackService.saveMovieProgress(
            profileId, p.contentId, state.position, state.duration);
      } else {
        await _playbackService.saveEpisodeProgress(
            profileId, p.contentId, state.position, state.duration);
      }
    } catch (e) {
      debugPrint('[OTV-auto] progress save failed: $e');
    }
  }

  void _endCarSession() {
    _carProgressTimer?.cancel();
    _carProgressTimer = null;
    _carItem = null;
    _carQueue = const [];
  }

  MediaItem _toItem(CarPlayable p) => MediaItem(
        id: p.mediaId,
        title: p.title,
        artist: p.subtitle,
        artUri: p.artUri,
        playable: true,
      );
}
