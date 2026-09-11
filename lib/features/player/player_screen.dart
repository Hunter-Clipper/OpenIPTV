import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/episode.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/parsers/xtream_client.dart';
import 'package:open_iptv/core/providers/channel_providers.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/native_video_player.dart';
import 'package:open_iptv/core/services/now_playing_service.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/features/player/player_controls.dart';
import 'package:open_iptv/ui/platform_helper.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    this.contentId,
    this.contentType,
    this.resumePosition,
    this.seriesId,
  });

  final String streamUrl;
  final String title;
  final String? contentId;
  final String? contentType;
  final Duration? resumePosition;
  // Only set for episodes — used to load the next episode on completion.
  final String? seriesId;

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final PlaybackService _playbackService;
  bool _textureReady = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  // Wraps the PlayerControls overlay so the hide-timer can check whether the
  // D-pad cursor is still somewhere inside it (ExcludeFocus below evicts any
  // focus inside once controls are hidden, handing focus back to the root
  // Focus so channel-up/down and the reveal-on-select key handler keep
  // working while the overlay is gone).
  final FocusNode _controlsFocusNode =
      FocusNode(debugLabel: 'PlayerControls', canRequestFocus: false, skipTraversal: true);
  // Focus lands here whenever the controls are revealed, so the D-pad can
  // navigate the overlay immediately without an extra "warm-up" press.
  final FocusNode _playPauseFocusNode = FocusNode(debugLabel: 'PlayPause');
  // The screen's own surface, held while controls are hidden. ExcludeFocus
  // evicting a focused control doesn't reliably land focus back here on its
  // own (Flutter's default unfocus disposition can hand it to an outer
  // FocusScope instead, e.g. the Navigator's), so hiding the controls always
  // explicitly reclaims this node — otherwise a hidden screen's key handler
  // (channel up/down, reveal-on-select) silently stops receiving events.
  final FocusNode _rootFocusNode = FocusNode(debugLabel: 'PlayerRoot');
  bool _resumeDialogShown = false;
  // Start true so the overlay covers corrupt decoder warmup frames.
  bool _isBuffering = true;
  StreamSubscription<NativeVideoPlayerState>? _stateSub;
  // Decoded CC/subtitle cue text — the native engine forwards this (Flutter,
  // not ExoPlayer, owns rendering, matching the previous mpv-based setup's
  // subtitle overlay). Empty string means "nothing showing right now".
  String _cueText = '';
  StreamSubscription<String>? _cueSub;
  // Tracks the last non-zero position independently of player state, so that
  // reconnection (which temporarily resets state.position to zero) doesn't
  // corrupt the progress save on dispose.
  Duration _lastKnownPosition = Duration.zero;
  Duration _lastKnownDuration = Duration.zero;

  // Set true once completion has been handled to prevent double-firing
  // (both the completed flag and the position-based fallback can fire).
  bool _completionHandled = false;
  // Set true once we've saved 100% progress on natural completion, so that
  // dispose()'s _saveProgressIfNeeded() doesn't overwrite with a stale value.
  bool _completionSaved = false;

  // Up Next state (episodes only).
  Episode? _nextEpisode;
  bool _showUpNext = false;
  // Set before pushReplacement so dispose() skips stop() and orientation-reset,
  // avoiding races with the new screen's play() on the shared engine.
  bool _navigatingToNext = false;
  // Guards position/duration/completed handling against stale state events
  // that fire before play() has actually started the new media. Without this,
  // the new PlayerScreen picks up the previous episode's end-position and
  // immediately triggers completion (skipping the new episode entirely).
  bool _playbackStarted = false;

  // Auto-recovery: stall detection + reconnect.
  static const _stallTimeout = Duration(seconds: 5);
  static const _maxRetries = 5;
  int _retryCount = 0;
  bool _isRecovering = false;
  Timer? _stallTimer;

  // Live pause/rewind. _currentUrl tracks whatever URL is actually open right
  // now (the plain live stream, or a dynamically-built catch-up window) —
  // widget.streamUrl only ever reflects the original live URL, so recovery/
  // reconnect logic must use _currentUrl instead once either tier kicks in.
  late String _currentUrl;
  Channel? _liveChannel;
  Source? _liveSource;
  // True once a catch-up-enabled channel has been switched into full DVR
  // scrubbing (real seek bar via _VodControls) by pausing/rewinding.
  bool _liveDvrActive = false;
  static const _dvrWindowDefault = Duration(hours: 1);
  // Non-catch-up channels: local decoder-cache-only pause/rewind, hard-capped —
  // there is no server-side archive to fall back on beyond this.
  static const _maxLocalBuffer = Duration(seconds: 30);
  Duration _liveOffset = Duration.zero;
  DateTime? _livePausedAt;
  bool _isBehindLive = false;

  bool get _isLive =>
      widget.contentType == 'live' || widget.contentType == null;

  // Channel-based playback (live or catch-up) as opposed to movie/episode
  // VOD — covers both ways a viewer ends up watching catch-up: pausing/
  // rewinding out of live (_enterLiveDvr, starts as 'live'), and picking a
  // specific past programme from the EPG guide directly (epg_panel.dart's
  // _playCatchup, starts as 'catchup'). Both need the same "Go Live"
  // affordance and the same live/catch-up controls switch, so this — not
  // widget.contentType, which never changes after construction — is what
  // drives that UI once _liveDvrActive can flip either way.
  bool get _isChannelPlayback =>
      _isLive || widget.contentType == 'catchup';

  // ref can throw "Bad state: Cannot use ref after the widget was disposed"
  // when read from dispose() — observed after popping straight back out of
  // catch-up playback. Best-effort like _updateNowPlayingMetadata(): a failed
  // profile lookup must never block the teardown that follows it.
  String? get _profileId {
    try {
      return ref.read(activeProfileProvider).valueOrNull?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    // Lock to landscape for immersive playback.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _playbackService = ref.read(playbackServiceProvider);
    _playbackService.ensureTexture().then((_) {
      if (mounted) setState(() => _textureReady = true);
    });
    _currentUrl = widget.streamUrl;
    // A guide-picked catch-up programme starts life already "in DVR mode"
    // for this channel — there's no separate live-then-rewind transition to
    // flip it on, since this screen was launched straight into catch-up.
    _liveDvrActive = widget.contentType == 'catchup';
    if (_isChannelPlayback && widget.contentId != null) {
      unawaited(_loadLiveChannelInfo());
    }

    // Buffering overlay stays up until the first real frame arrives
    // (state.hasVideo), hiding blocky decoder-warmup artifacts. Also tracks
    // last real position/duration and drives completion + stall detection.
    _stateSub = _playbackService.stateStream.listen((s) {
      if (!mounted) return;
      if (s.buffering && !s.hasVideo) {
        if (!_isBuffering) setState(() => _isBuffering = true);
        _startStallTimer();
      } else if (_isBuffering) {
        _cancelStallTimer();
        _retryCount = 0;
        setState(() {
          _isBuffering = false;
          _isRecovering = false;
        });
      }

      // Ignore stale state events until play() has actually started the new
      // media. Without this guard the new PlayerScreen picks up the previous
      // episode's end-position and immediately triggers completion.
      if (!_playbackStarted) return;
      final isPlainLive = _isLive && !_liveDvrActive;
      if (!isPlainLive) {
        if (s.position > Duration.zero) _lastKnownPosition = s.position;
        if (s.duration > Duration.zero) _lastKnownDuration = s.duration;
        if (!_completionHandled) {
          final remaining = _lastKnownDuration - s.position;
          final nearEnd = _lastKnownDuration > Duration.zero &&
              s.position > Duration.zero &&
              remaining.inSeconds <= 3;
          if (s.completed || nearEnd) {
            _completionHandled = true;
            _onPlaybackCompleted();
          }
        }
      }
    });

    _cueSub = _playbackService.cueStream.listen((text) {
      if (mounted) setState(() => _cueText = text);
    });

    HardwareKeyboard.instance.addHandler(_onAnyKeyEvent);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPlayback();
    });

    _showControls();
  }

  void _startStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = Timer(_stallTimeout, _onStall);
  }

  void _cancelStallTimer() {
    _stallTimer?.cancel();
    _stallTimer = null;
  }

  Future<void> _onStall() async {
    if (!mounted) return;
    if (_retryCount >= _maxRetries) {
      // Give up — show a permanent error state via the buffering overlay.
      setState(() {
        _isRecovering = false;
        _isBuffering = true;
      });
      return;
    }
    _retryCount++;
    setState(() => _isRecovering = true);
    debugPrint('[OTV-recovery] stall detected — attempt $_retryCount/$_maxRetries');
    final position = (_isLive && !_liveDvrActive) ? null : _lastKnownPosition;
    await _playbackService.play(_currentUrl, startPosition: position);
    if (_isLive && !_liveDvrActive && _liveOffset > Duration.zero) {
      // Reconnecting a plain live stream always lands back at the live edge —
      // any local-buffer rewind offset no longer applies.
      _liveOffset = Duration.zero;
      _livePausedAt = null;
      if (mounted) setState(() => _isBehindLive = false);
    }
    // Restart stall timer for the new attempt.
    _startStallTimer();
  }

  // Best-effort — only needed to know whether this channel supports catch-up
  // and to have credentials on hand if the user pauses/rewinds. A failure
  // just leaves the channel treated as non-catch-up (local buffer only).
  Future<void> _loadLiveChannelInfo() async {
    final id = widget.contentId;
    if (id == null) return;
    try {
      final channel = await _playbackService.db.getChannelById(id);
      if (!mounted || channel == null) return;
      Source? source;
      if (channel.hasCatchup) {
        source = await _playbackService.db.getSourceById(channel.sourceId);
      }
      if (!mounted) return;
      setState(() {
        _liveChannel = channel;
        _liveSource = source;
      });
    } catch (_) {
      // Ignore — falls back to non-catch-up behavior.
    }
  }

  bool get _liveHasCatchup => _liveChannel?.hasCatchup ?? false;

  Future<void> _onLivePlayPause() async {
    if (_liveDvrActive) return; // _VodControls owns play/pause once active.
    if (_liveHasCatchup) {
      await _enterLiveDvr(startPaused: true);
      return;
    }
    final playing = _playbackService.lastState.playing;
    if (playing) {
      _livePausedAt = DateTime.now();
      await _playbackService.pause();
    } else {
      if (_livePausedAt != null) {
        _liveOffset += DateTime.now().difference(_livePausedAt!);
        _livePausedAt = null;
      }
      if (_liveOffset > _maxLocalBuffer) {
        await _goLiveLocal();
        return;
      }
      await _playbackService.resume();
    }
    if (mounted) setState(() => _isBehindLive = _liveOffset > Duration.zero);
  }

  Future<void> _onLiveRewind() async {
    if (_liveDvrActive) return;
    if (_liveHasCatchup) {
      await _enterLiveDvr(initialRewind: const Duration(seconds: 10));
      return;
    }
    if (_liveOffset >= _maxLocalBuffer) return;
    const step = Duration(seconds: 10);
    await _playbackService.seekRelative(-step);
    _liveOffset =
        (_liveOffset + step) > _maxLocalBuffer ? _maxLocalBuffer : _liveOffset + step;
    if (mounted) setState(() => _isBehindLive = true);
  }

  Future<void> _onLiveForward() async {
    if (_liveDvrActive) return;
    if (_liveOffset <= Duration.zero) return;
    const step = Duration(seconds: 10);
    if (_liveOffset <= step) {
      await _goLiveLocal();
      return;
    }
    await _playbackService.seekRelative(step);
    _liveOffset -= step;
    if (mounted) setState(() {});
  }

  // Non-catch-up "jump to live" — just reopens the plain live URL fresh,
  // since there's no server-side archive to resume a stale position from.
  Future<void> _goLiveLocal() async {
    _liveOffset = Duration.zero;
    _livePausedAt = null;
    _currentUrl = widget.streamUrl;
    await _playbackService.play(widget.streamUrl);
    if (mounted) setState(() => _isBehindLive = false);
  }

  // Switches a catch-up-enabled live channel into full DVR scrubbing: opens
  // a timeshift window ending at "now" and seeks to the tail of it (minus
  // [initialRewind]), so _VodControls' existing seek bar/skip/pause controls
  // take over from here — no separate scrubbing UI needed.
  Future<void> _enterLiveDvr({
    bool startPaused = false,
    Duration initialRewind = Duration.zero,
  }) async {
    final channel = _liveChannel;
    final source = _liveSource;
    if (channel?.streamId == null ||
        source?.xtreamHost == null ||
        source?.xtreamUsername == null ||
        source?.xtreamPassword == null) {
      return;
    }
    final maxWindow = Duration(days: channel!.catchupDays);
    final window =
        _dvrWindowDefault < maxWindow ? _dvrWindowDefault : maxWindow;
    if (window <= Duration.zero) return;
    final windowStart = DateTime.now().subtract(window);
    final client = XtreamClient(
      host: source!.xtreamHost!,
      username: source.xtreamUsername!,
      password: source.xtreamPassword!,
      sourceId: source.id,
    );
    final url = client.buildCatchupUrl(channel.streamId!, windowStart, window);
    client.dispose();

    _completionHandled = false;
    _playbackStarted = false;
    _currentUrl = url;
    setState(() => _liveDvrActive = true);
    debugPrint('[OTV-dvr] _enterLiveDvr: _liveDvrActive set to true');
    final tail = window - initialRewind;
    // Route the initial seek through play()'s own startPosition handling —
    // it waits for the engine to report a real duration before seeking. A
    // bare seek() called right after play() can silently no-op if the
    // container hasn't been parsed yet, leaving the app's idea of "current
    // position" out of sync with the engine's actual position — every
    // subsequent relative rewind/forward then compounds off that wrong
    // position, which looked like rewind jumping to "random" times.
    await _playbackService.play(
      url,
      startPosition: tail.isNegative ? Duration.zero : tail,
    );
    _playbackStarted = true;
    if (startPaused) await _playbackService.pause();
  }

  // Exits DVR mode back to true live — used both by the manual "Go Live"
  // button and by auto-snap when playback reaches the tail of the DVR window.
  //
  // widget.streamUrl is only the true live URL for the live-then-rewind
  // entry path; a guide-picked catch-up screen was launched with the
  // catch-up URL as widget.streamUrl, so _liveChannel's own streamUrl
  // (loaded in initState for both entry paths) is the real source of truth.
  Future<void> _goLive() async {
    _completionHandled = false;
    _playbackStarted = false;
    final liveUrl = _liveChannel?.streamUrl ?? widget.streamUrl;
    _currentUrl = liveUrl;
    setState(() => _liveDvrActive = false);
    debugPrint('[OTV-dvr] _goLive: _liveDvrActive set to false');
    await _playbackService.play(liveUrl);
    _playbackStarted = true;
  }

  // Classic-cable-box channel up/down, driven by the D-pad/remote (see
  // _handleKeyEvent below). Re-tunes by pushReplacement-ing a fresh
  // PlayerScreen for the neighboring channel in allChannelsProvider's
  // order — the same shared-engine hand-off pattern catch-up uses, so it
  // needs the same markTransitioning() guard against this screen's dispose()
  // undoing the new screen's just-started playback.
  Future<void> _changeChannel(int delta) async {
    final channel = _liveChannel;
    if (channel == null) return;
    final channels = ref.read(allChannelsProvider).valueOrNull;
    if (channels == null || channels.isEmpty) return;
    final index = channels.indexWhere((c) => c.id == channel.id);
    if (index == -1) return;
    final next =
        channels[((index + delta) % channels.length + channels.length) %
            channels.length];
    if (next.id == channel.id) return;

    _playbackService.markTransitioning();
    context.pushReplacement('/player', extra: {
      'streamUrl': next.streamUrl,
      'title': next.name,
      'contentType': 'live',
      'contentId': next.id,
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // This only fires while the root Focus itself holds primary focus —
    // i.e. the controls are hidden (ExcludeFocus evicted them) and nothing
    // else claimed the key first. Reveal the overlay and hand focus to it
    // rather than acting on the press directly, matching remote-control
    // convention (press OK to bring up controls, press again to act).
    if (!_controlsVisible &&
        node.hasPrimaryFocus &&
        (key == LogicalKeyboardKey.select ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.gameButtonA)) {
      _showControls();
      return KeyEventResult.handled;
    }

    if (!_isChannelPlayback) return KeyEventResult.ignored;
    // Dedicated channel-up/down remote buttons always work; the arrow keys
    // only double as channel-up/down when this screen's own surface holds
    // focus directly (not one of the on-screen control buttons) — otherwise
    // they're left alone for normal control-to-control D-pad navigation.
    final isUp = key == LogicalKeyboardKey.channelUp ||
        (key == LogicalKeyboardKey.arrowUp && node.hasPrimaryFocus);
    final isDown = key == LogicalKeyboardKey.channelDown ||
        (key == LogicalKeyboardKey.arrowDown && node.hasPrimaryFocus);
    if (isUp) {
      unawaited(_changeChannel(1));
      return KeyEventResult.handled;
    }
    if (isDown) {
      unawaited(_changeChannel(-1));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // Shows the controls overlay (if hidden), (re)starts the auto-hide
  // countdown, and moves D-pad focus onto the play/pause button so arrow
  // keys can navigate the overlay immediately.
  void _showControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _resetHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playPauseFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _stallTimer?.cancel();
    _stateSub?.cancel();
    _cueSub?.cancel();
    HardwareKeyboard.instance.removeHandler(_onAnyKeyEvent);
    _controlsFocusNode.dispose();
    _playPauseFocusNode.dispose();
    _rootFocusNode.dispose();
    // When transitioning to the next episode (pushReplacement from within
    // this same screen) or to a different content type entirely (e.g. an
    // external pushReplacement from the EPG panel into catch-up), skip the
    // orientation/UI reset and stop() so the new screen's landscape lock and
    // just-started playback aren't undone by this dispose() running after
    // the new screen's initState() already took over the shared engine.
    final skipTeardown =
        _navigatingToNext || _playbackService.consumeTransitioning();
    if (!skipTeardown) {
      // A TV has no portrait mode at all — restoring one here would
      // letterbox the whole app into a small portrait compat box on every
      // exit from playback.
      if (!PlatformHelper.isTVDevice) {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    // A failed progress save must never block the stop() below — that
    // regressed catch-up playback into running forever in the background
    // (see _profileId's ref-after-dispose note above).
    try {
      _saveProgressIfNeeded();
    } catch (e) {
      debugPrint('[OTV-save] _saveProgressIfNeeded failed: $e');
    }
    if (!skipTeardown) {
      _playbackService.stop();
      nowPlayingHandler.stop();
    }
    super.dispose();
  }

  Future<void> _startPlayback() async {
    // Stamp last-watched time for live channels so Recently Watched updates.
    final profileId = _profileId;
    if (_isLive && widget.contentId != null && profileId != null) {
      await _playbackService.db
          .updateChannelLastWatched(profileId, widget.contentId!);
    }
    final service = _playbackService;

    // Show resume dialog if there is a saved position and user didn't
    // explicitly choose "Start Over" (i.e. resumePosition != Duration.zero).
    if (!_isLive &&
        widget.resumePosition != null &&
        widget.resumePosition!.inSeconds > 0 &&
        !_resumeDialogShown) {
      _resumeDialogShown = true;
      if (!mounted) return;
      final resume = await _showResumeDialog(widget.resumePosition!);
      if (!mounted) return;
      // null = tapped outside dialog → exit the player
      if (resume == null) {
        context.pop();
        return;
      }
      _lastKnownPosition = Duration.zero;
      _lastKnownDuration = Duration.zero;
      await service.play(
        widget.streamUrl,
        startPosition: resume ? widget.resumePosition : null,
      );
      _playbackStarted = true;
    } else {
      _lastKnownPosition = Duration.zero;
      _lastKnownDuration = Duration.zero;
      await service.play(
        widget.streamUrl,
        startPosition: widget.resumePosition == Duration.zero
            ? null
            : widget.resumePosition,
      );
      _playbackStarted = true;
    }
    unawaited(_updateNowPlayingMetadata());
  }

  // Best-effort — a lookup failure must never block or crash playback, so
  // errors here just fall back to the bare title with no artwork/subtitle.
  Future<void> _updateNowPlayingMetadata() async {
    String? artist;
    Uri? artUri;
    try {
      final id = widget.contentId;
      if (id != null) {
        if (_isLive) {
          final channel = await _playbackService.db.getChannelById(id);
          if (channel?.logoUrl != null) artUri = Uri.tryParse(channel!.logoUrl!);
          final programme =
              await ref.read(epgServiceProvider).getCurrentProgramme(id);
          artist = programme?.title;
        } else if (widget.contentType == 'movie') {
          final movie = await _playbackService.db.watchMovieById(id).first;
          if (movie?.posterUrl != null) artUri = Uri.tryParse(movie!.posterUrl!);
        } else if (widget.contentType == 'episode') {
          final episode = await _playbackService.db.getEpisodeById(id);
          if (episode?.stillUrl != null) artUri = Uri.tryParse(episode!.stillUrl!);
        }
      }
    } catch (_) {
      // Ignore — fall back to bare title below.
    }
    if (!mounted) return;
    nowPlayingHandler.setNowPlaying(widget.title, artist: artist, artUri: artUri);
  }

  // Returns true=resume, false=start over, null=dismissed (tap outside → exit).
  Future<bool?> _showResumeDialog(Duration position) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resume Watching?'),
        content: Text('Continue from ${_formatDuration(position)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Start Over'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  void _saveProgressIfNeeded() {
    if (_isLive) return;
    // Completion already saved 100% — don't overwrite with stale position.
    if (_completionSaved) return;
    final id = widget.contentId;
    if (id == null) return;
    final service = _playbackService;
    // Use _lastKnownPosition (tracked via the state stream) rather than
    // reading service.lastState.position directly — the latter can be zero
    // if a reconnection attempt called play() and the seek hasn't
    // completed yet.
    final position = _lastKnownPosition;
    // Prefer the stream-tracked duration; fall back to the last known state.
    final total = _lastKnownDuration > Duration.zero
        ? _lastKnownDuration
        : service.lastState.duration;
    debugPrint('[OTV-save] type=${widget.contentType} id=$id pos=${position.inSeconds}s total=${total.inSeconds}s');
    final profileId = _profileId;
    if (profileId == null) return;
    if (widget.contentType == 'movie') {
      service.saveMovieProgress(profileId, id, position, total);
    } else if (widget.contentType == 'episode') {
      service.saveEpisodeProgress(profileId, id, position, total);
    }
  }

  Future<void> _onPlaybackCompleted() async {
    if (!mounted) return;
    // Reached the tail of a catch-up DVR window — snap back to true live
    // instead of falling through to the movie/episode/pop logic below.
    if (_liveDvrActive) {
      await _goLive();
      return;
    }
    final id = widget.contentId;
    final total = _lastKnownDuration;

    // Save as fully watched.
    final profileId = _profileId;
    if (id != null && total > Duration.zero && profileId != null) {
      _completionSaved = true;
      if (widget.contentType == 'movie') {
        await _playbackService.saveMovieProgress(profileId, id, total, total);
      } else if (widget.contentType == 'episode') {
        await _playbackService.saveEpisodeProgress(profileId, id, total, total);
      }
    }
    if (!mounted) return;

    // For episodes: look for the next episode in the series.
    if (widget.contentType == 'episode' && widget.seriesId != null) {
      final episodes = await _playbackService.db
          .getEpisodesForSeries(widget.seriesId!, profileId: profileId);
      final idx = episodes.indexWhere((e) => e.id == id);
      if (idx >= 0 && idx + 1 < episodes.length) {
        if (mounted) {
          setState(() {
            _nextEpisode = episodes[idx + 1];
            _showUpNext = true;
          });
        }
        return;
      }
    }

    // Movies, or last episode of a series: just exit the player.
    if (mounted) context.pop();
  }

  void _playNextEpisode() {
    final ep = _nextEpisode;
    if (ep == null || !mounted) return;
    _navigatingToNext = true;
    context.pushReplacement('/player', extra: {
      'streamUrl': ep.streamUrl,
      'title': '${ep.episodeLabel} – ${ep.title}',
      'contentId': ep.id,
      'contentType': 'episode',
      'seriesId': ep.seriesId,
      'resumePosition': ep.isInProgress ? ep.watchedDuration : null,
    });
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) _hideControls();
    });
  }

  // Arrow-key focus traversal within the controls is handled by Flutter's
  // default focus shortcuts, not by anything in this screen's own key
  // handlers — so it would otherwise never reset the hide countdown. This
  // raw, non-consuming hook sees every key press regardless of who ends up
  // handling it, which is what actually lets D-pad navigation count as
  // "still active" without keeping the controls up forever just because
  // some button happens to still have focus.
  bool _onAnyKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && _controlsVisible) {
      _resetHideTimer();
    }
    return false;
  }

  void _hideControls() {
    setState(() => _controlsVisible = false);
    _rootFocusNode.requestFocus();
  }

  void _onTap() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      _hideControls();
    } else {
      _showControls();
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Widget _buildVideoSurface() {
    if (!_textureReady) return const SizedBox.shrink();
    return Texture(textureId: _playbackService.textureId);
  }

  Widget _buildCueOverlay() {
    if (_cueText.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 24,
      right: 24,
      bottom: 24,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.black54,
            child: Text(
              _cueText,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inPip = ref.watch(pipActiveProvider);
    if (inPip) {
      // Bare video surface only — no controls/overlays fit the tiny PiP window.
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [_buildVideoSurface(), _buildCueOverlay()],
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _rootFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideoSurface(),
            _buildCueOverlay(),
            // Buffering / recovery overlay.
            AnimatedOpacity(
              opacity: _isBuffering ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_isBuffering,
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: _retryCount >= _maxRetries
                        ? _ErrorOverlay(
                            title: widget.title,
                            onRetry: () {
                              setState(() {
                                _retryCount = 0;
                                _isRecovering = false;
                              });
                              _startPlayback();
                            },
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                  color: Colors.white),
                              const SizedBox(height: 16),
                              Text(
                                _isRecovering
                                    ? 'Reconnecting… ($_retryCount/$_maxRetries)'
                                    : widget.title,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            // Controls overlay
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: ExcludeFocus(
                  excluding: !_controlsVisible,
                  child: Focus(
                    focusNode: _controlsFocusNode,
                    child: PlayerControls(
                      title: widget.title,
                      contentType: _isChannelPlayback
                          ? (_liveDvrActive ? 'catchup' : 'live')
                          : widget.contentType,
                      contentId: widget.contentId,
                      isLive: _isChannelPlayback && !_liveDvrActive,
                      isLiveDvr: _liveDvrActive,
                      onTap: _onTap,
                      onLivePlayPause: _onLivePlayPause,
                      onLiveRewind: _onLiveRewind,
                      onLiveForward: _onLiveForward,
                      onGoLive: _liveDvrActive
                          ? _goLive
                          : (_isBehindLive ? _goLiveLocal : null),
                      isBehindLive: _isBehindLive,
                      playPauseFocusNode: _playPauseFocusNode,
                    ),
                  ),
                ),
              ),
            ),
            // Up Next banner — shown when an episode finishes and a next one exists.
            if (_showUpNext && _nextEpisode != null)
              _UpNextBanner(
                episode: _nextEpisode!,
                onPlay: _playNextEpisode,
                onDismiss: () =>
                    setState(() => _showUpNext = false),
              ),
          ],
        ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Up Next banner (episodes only)
// ---------------------------------------------------------------------------

class _UpNextBanner extends StatefulWidget {
  const _UpNextBanner({
    required this.episode,
    required this.onPlay,
    required this.onDismiss,
  });

  final Episode episode;
  final VoidCallback onPlay;
  final VoidCallback onDismiss;

  @override
  State<_UpNextBanner> createState() => _UpNextBannerState();
}

class _UpNextBannerState extends State<_UpNextBanner> {
  static const _totalSeconds = 7;
  int _remaining = _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_remaining <= 1) {
        t.cancel();
        widget.onPlay();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 60,
      right: 20,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'UP NEXT',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.episode.episodeLabel} – ${widget.episode.title}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: 1.0 - (_remaining / _totalSeconds),
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 2,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: widget.onPlay,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Play Now ($_remaining)'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: widget.onDismiss,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.title, required this.onRetry});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.signal_wifi_connected_no_internet_4,
            color: Colors.white54, size: 48),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        const Text(
          'Stream unavailable',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Try Again'),
        ),
      ],
    );
  }
}
