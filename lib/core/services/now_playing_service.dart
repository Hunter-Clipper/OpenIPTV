import 'package:audio_service/audio_service.dart';
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
      androidNotificationChannelId: 'com.openiptv.open_iptv.now_playing',
      androidNotificationChannelName: 'Now Playing',
      androidNotificationIcon: 'drawable/ic_stat_open_iptv',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

/// Mirrors [PlaybackService]'s media_kit player state into a system media
/// notification with transport controls (play/pause/stop), so users can see
/// and control what's playing from the notification shade or lock screen.
///
/// [setEnabled] gates every visible side effect — the underlying player state
/// stream listeners run for the app's whole lifetime, so without this check
/// the notification would keep reappearing on every play/pause change
/// regardless of the user's "Media Notification" setting.
class NowPlayingHandler extends BaseAudioHandler {
  NowPlayingHandler(this._playbackService) {
    final player = _playbackService.player;
    player.stream.playing.listen((_) => _broadcastState());
    player.stream.buffering.listen((_) => _broadcastState());
    player.stream.position.listen((_) => _broadcastState());
    player.stream.duration.listen((_) => _broadcastState());
  }

  final PlaybackService _playbackService;
  bool _enabled = true;
  // Starts true (nothing playing yet). Guards against the player's state
  // streams re-pushing a non-idle PlaybackState after stop() — media_kit's
  // stop() is async and its playing/buffering stream events can arrive after
  // our idle state, which would otherwise leave the notification stuck
  // instead of torn down. Cleared by setNowPlaying(), set by stop().
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
    _stopped = false;
    final duration = _playbackService.player.state.duration;
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
    final state = _playbackService.player.state;
    playbackState.add(PlaybackState(
      controls: [
        state.playing ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1],
      playing: state.playing,
      processingState: state.buffering
          ? AudioProcessingState.buffering
          : AudioProcessingState.ready,
      updatePosition: state.position,
    ));
  }

  @override
  Future<void> play() => _playbackService.resume();

  @override
  Future<void> pause() => _playbackService.pause();

  @override
  Future<void> seek(Duration position) => _playbackService.seek(position);

  @override
  Future<void> stop() async {
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
}
