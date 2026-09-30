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
import 'package:open_iptv/features/player/channel_switcher.dart';
import 'package:open_iptv/features/player/player_controls.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/utils/format.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/shared/widgets/video_surface.dart';
import 'package:open_iptv/ui/platform_helper.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
    this.contentId,
    this.contentType,
    this.resumePosition,
    this.confirmResume = true,
    this.seriesId,
  });

  final String streamUrl;
  final String title;
  final String? contentId;
  final String? contentType;
  final Duration? resumePosition;
  // False when the caller's own button already was the choice ("Resume
  // from 0:18") — asking "Resume watching?" again would be redundant. True
  // for implicit resumes (tapping an in-progress episode), where the dialog
  // is the only way to start over.
  final bool confirmResume;
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
  final FocusNode _controlsFocusNode = FocusNode(
      debugLabel: 'PlayerControls',
      canRequestFocus: false,
      skipTraversal: true);
  // Focus lands here whenever the controls are revealed, so the D-pad can
  // navigate the overlay immediately without an extra "warm-up" press.
  final FocusNode _playPauseFocusNode = FocusNode(debugLabel: 'PlayPause');
  // Fallback target for the edge-aware Up/Left override below — Flutter's
  // own directional traversal has no good candidate directly above the
  // centered play/pause button, nor to the left of the CC button past the
  // (non-focusable) title text, so either press would otherwise silently do
  // nothing instead of reaching the screen-edge Back button.
  final FocusNode _backFocusNode = FocusNode(debugLabel: 'PlayerBack');
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
  StreamSubscription<NativePlaybackError>? _errorSub;
  // Set when the provider says a stream doesn't exist / isn't allowed —
  // shown instead of the generic "Stream unavailable".
  String? _errorMessage;
  // True once the provider has refused this stream (see _errorSub). The
  // engine keeps emitting idle, non-buffering state afterwards, which would
  // otherwise read as "recovered" and hide the error overlay immediately.
  bool _playbackFailed = false;
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

  // Live at the live edge — no seekable timeline, no progress to track.
  bool get _isPlainLive => _isLive && !_liveDvrActive;

  // Channel-based playback (live or catch-up) as opposed to movie/episode
  // VOD — covers both ways a viewer ends up watching catch-up: pausing/
  // rewinding out of live (_enterLiveDvr, starts as 'live'), and picking a
  // specific past programme from the EPG guide directly (epg_panel.dart's
  // _playCatchup, starts as 'catchup'). Both need the same "Go Live"
  // affordance and the same live/catch-up controls switch, so this — not
  // widget.contentType, which never changes after construction — is what
  // drives that UI once _liveDvrActive can flip either way.
  // The error screen has its own buttons (Try again / Channels / Go back);
  // the regular controls would draw over it.
  bool get _playbackGaveUp => _retryCount >= _maxRetries;
  bool get _showOverlayControls => _controlsVisible && !_playbackGaveUp;

  bool get _isChannelPlayback => _isLive || widget.contentType == 'catchup';

  // Captured while mounted and kept current via listenManual, because
  // reading ref from dispose() throws ("Cannot use ref after the widget was
  // disposed") — which previously made the exit-time progress save silently
  // skip, so leaving a movie/episode part-way never saved its position.
  String? _profileId;

  @override
  void initState() {
    super.initState();
    _profileId = ref.read(activeProfileIdProvider);
    ref.listenManual<String?>(
        activeProfileIdProvider, (_, next) => _profileId = next);
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
    // A failed stream goes idle rather than buffering, so without this the
    // overlay would hide and leave the last frame on screen with nothing
    // retrying. Permanent HTTP failures show a message right away; anything
    // else reconnects now instead of waiting for the stall timer.
    _errorSub = _playbackService.errorStream.listen((e) {
      if (!mounted) return;
      _cancelStallTimer();
      if (e.isPermanent) {
        setState(() {
          _playbackFailed = true;
          _retryCount = _maxRetries;
          _isRecovering = false;
          _isBuffering = true;
          _errorMessage = e.httpStatus == 401 || e.httpStatus == 403
              ? "Your provider didn't allow this stream."
              : _isChannelPlayback
                  ? "This channel isn't available from your provider right now."
                  : "This title isn't available from your provider right now.";
        });
      } else {
        setState(() => _isBuffering = true);
        unawaited(_onStall());
      }
    });
    _stateSub = _playbackService.stateStream.listen((s) {
      if (!mounted) return;
      if (_playbackFailed) return;
      if (s.buffering && !s.hasVideo) {
        if (!_isBuffering) setState(() => _isBuffering = true);
        _startStallTimer();
      } else if (_isBuffering && (s.playing || s.hasVideo)) {
        // Only real playback clears the overlay and the retry count — an
        // idle engine after a failed attempt isn't "recovered", and treating
        // it as such reset _retryCount every time, so retries never ended.
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
      if (!_isPlainLive) {
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
    debugPrint(
        '[OTV-recovery] stall detected — attempt $_retryCount/$_maxRetries');
    final position = _isPlainLive ? null : _lastKnownPosition;
    await _playbackService.play(_currentUrl, startPosition: position);
    if (_isPlainLive && _liveOffset > Duration.zero) {
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
    // Paused counts as behind live too — the offset only accrues on resume,
    // but "GO LIVE" should be available (and the badge say so) right away.
    if (mounted) {
      setState(() =>
          _isBehindLive = _livePausedAt != null || _liveOffset > Duration.zero);
    }
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
    _liveOffset = (_liveOffset + step) > _maxLocalBuffer
        ? _maxLocalBuffer
        : _liveOffset + step;
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
    final client = XtreamClient.fromSource(source!);
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
    final next = channels[
        ((index + delta) % channels.length + channels.length) %
            channels.length];
    if (next.id == channel.id) return;
    _tuneTo(next);
  }

  void _tuneTo(Channel next) {
    if (next.id == widget.contentId && !_liveDvrActive) return;
    _playbackService.markTransitioning();
    context.pushReplacement('/player', extra: {
      'streamUrl': next.streamUrl,
      'title': next.name,
      'contentType': 'live',
      'contentId': next.id,
    });
  }

  // Slides in the channel list over the video; picking one tunes to it.
  Future<void> _openChannels() async {
    final id = widget.contentId;
    if (!_isChannelPlayback || id == null) return;
    _hideTimer?.cancel();
    final picked = await showChannelSwitcher(context, id);
    if (!mounted) return;
    if (picked != null) {
      _tuneTo(picked);
    } else if (!_playbackGaveUp) {
      _showControls();
    }
    // (On the error screen, closing the list hands focus back to its own
    // Channels button — route pop restores it.)
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
    // With the controls hidden, Right (or the remote's Guide/Info key)
    // brings up the channel list.
    if (node.hasPrimaryFocus &&
        (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.guide)) {
      unawaited(_openChannels());
      return KeyEventResult.handled;
    }
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
    _errorSub?.cancel();
    _cueSub?.cancel();
    HardwareKeyboard.instance.removeHandler(_onAnyKeyEvent);
    _controlsFocusNode.dispose();
    _playPauseFocusNode.dispose();
    _backFocusNode.dispose();
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
      unawaited(_playbackService.db
          .updateChannelLastWatched(profileId, widget.contentId!));
    }

    // Show resume dialog if there is a saved position and user didn't
    // explicitly choose "Start Over" (i.e. resumePosition != Duration.zero).
    if (!_isLive &&
        widget.resumePosition != null &&
        widget.resumePosition!.inSeconds > 0 &&
        widget.confirmResume &&
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
      await _playbackService.play(
        widget.streamUrl,
        startPosition: resume ? widget.resumePosition : null,
      );
      _playbackStarted = true;
    } else {
      _lastKnownPosition = Duration.zero;
      _lastKnownDuration = Duration.zero;
      await _playbackService.play(
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
          if (channel?.logoUrl != null) {
            artUri = Uri.tryParse(channel!.logoUrl!);
          }
          final programme =
              await ref.read(epgServiceProvider).getCurrentProgramme(id);
          artist = programme?.title;
        } else if (widget.contentType == 'movie') {
          final movie = await _playbackService.db.watchMovieById(id).first;
          if (movie?.posterUrl != null) {
            artUri = Uri.tryParse(movie!.posterUrl!);
          }
        } else if (widget.contentType == 'episode') {
          final episode = await _playbackService.db.getEpisodeById(id);
          if (episode?.stillUrl != null) {
            artUri = Uri.tryParse(episode!.stillUrl!);
          }
        }
      }
    } catch (_) {
      // Ignore — fall back to bare title below.
    }
    if (!mounted) return;
    nowPlayingHandler.setNowPlaying(widget.title,
        artist: artist, artUri: artUri);
  }

  // Returns true=resume, false=start over, null=dismissed (tap outside → exit).
  Future<bool?> _showResumeDialog(Duration position) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resume Watching?'),
        content: Text('Continue from ${formatClock(position)}?'),
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
    // Use _lastKnownPosition (tracked via the state stream) rather than
    // reading _playbackService.lastState.position directly — the latter can be zero
    // if a reconnection attempt called play() and the seek hasn't
    // completed yet.
    final position = _lastKnownPosition;
    // Prefer the stream-tracked duration; fall back to the last known state.
    final total = _lastKnownDuration > Duration.zero
        ? _lastKnownDuration
        : _playbackService.lastState.duration;
    debugPrint(
        '[OTV-save] type=${widget.contentType} id=$id pos=${position.inSeconds}s total=${total.inSeconds}s');
    final profileId = _profileId;
    if (profileId == null) return;
    _saveProgress(profileId, id, position, total);
  }

  // Dispatches to the movie or episode progress store; other content types
  // (live, catch-up) have no saved progress.
  Future<void> _saveProgress(
      String profileId, String id, Duration position, Duration total) async {
    if (widget.contentType == 'movie') {
      await _playbackService.saveMovieProgress(profileId, id, position, total);
    } else if (widget.contentType == 'episode') {
      await _playbackService.saveEpisodeProgress(
          profileId, id, position, total);
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
      await _saveProgress(profileId, id, total, total);
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
      'title': '${ep.episodeLabel} – ${ep.displayTitle}',
      'contentId': ep.id,
      'contentType': 'episode',
      'seriesId': ep.seriesId,
      'resumePosition': ep.isInProgress ? ep.watchedDuration : null,
    });
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      // A sheet or the channel list is open on top: hiding now would pull
      // focus out of it (the TV remote would lose its place). Wait.
      if (ModalRoute.of(context)?.isCurrent == false) {
        _resetHideTimer();
        return;
      }
      // Like mainstream players, keep the controls up while paused (the
      // user is likely about to act on them); re-check until playback
      // resumes, then hide as normal.
      if (!_playbackService.lastState.playing && !_isBuffering) {
        _resetHideTimer();
        return;
      }
      _hideControls();
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
    // The error screen owns focus (Try again / Channels / Go back); taking
    // it back to the surface would strand a TV remote.
    if (!_playbackGaveUp) _rootFocusNode.requestFocus();
  }

  void _onTap() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      _hideControls();
    } else {
      _showControls();
    }
  }

  Widget _buildVideoSurface() {
    if (!_textureReady) return const SizedBox.shrink();
    return VideoSurface(
      textureId: _playbackService.textureId,
      stateStream: _playbackService.stateStream,
      initialAspectRatio: _playbackService.lastState.aspectRatio,
      fit: ref.watch(videoFitProvider),
    );
  }

  Widget _buildCueOverlay({bool liftForControls = true}) {
    if (_cueText.isEmpty) return const SizedBox.shrink();
    // Lifted clear of the controls' bottom panel while it's showing.
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      left: 24,
      right: 24,
      bottom: liftForControls && _controlsVisible ? 180 : 24,
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
          children: [
            _buildVideoSurface(),
            _buildCueOverlay(liftForControls: false),
          ],
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
          // Swipe left (from anywhere) for the channel list on Live TV.
          onHorizontalDragEnd: _isChannelPlayback
              ? (d) {
                  if ((d.primaryVelocity ?? 0) < -400) {
                    unawaited(_openChannels());
                  }
                }
              : null,
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
                              message: _errorMessage,
                              onBack: () => context.pop(),
                              onChannels: _isChannelPlayback &&
                                      widget.contentId != null
                                  ? _openChannels
                                  : null,
                              onRetry: () {
                                setState(() {
                                  _retryCount = 0;
                                  _isRecovering = false;
                                  _errorMessage = null;
                                  _playbackFailed = false;
                                });
                                _startPlayback();
                              },
                            )
                          : _LoadingView(
                              // The controls already show the title and a
                              // spinner on the play button.
                              visible: !_controlsVisible,
                              title: widget.title,
                              status: _isRecovering
                                  ? 'Reconnecting… ($_retryCount of $_maxRetries)'
                                  : null,
                            ),
                    ),
                  ),
                ),
              ),
              // Controls overlay
              AnimatedOpacity(
                opacity: _showOverlayControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showOverlayControls,
                  child: ExcludeFocus(
                    excluding: !_showOverlayControls,
                    // Touch presses on the overlay restart the countdown, the
                    // same as D-pad presses do via _onAnyKeyEvent.
                    child: Listener(
                      onPointerDown: (_) {
                        if (_controlsVisible) _resetHideTimer();
                      },
                      child: Focus(
                        focusNode: _controlsFocusNode,
                        child: Actions(
                          actions: {
                            DirectionalFocusIntent:
                                EdgeAwareDirectionalFocusAction(
                              directions: {
                                TraversalDirection.up,
                                TraversalDirection.left,
                              },
                              onNoMove: () => _backFocusNode.requestFocus(),
                            ),
                          },
                          child: PlayerControls(
                            title: widget.title,
                            contentType: _isChannelPlayback
                                ? (_liveDvrActive ? 'catchup' : 'live')
                                : widget.contentType,
                            contentId: widget.contentId,
                            isLive: _isChannelPlayback && !_liveDvrActive,
                            isLiveDvr: _liveDvrActive,
                            onLivePlayPause: _onLivePlayPause,
                            onLiveRewind: _onLiveRewind,
                            onLiveForward: _onLiveForward,
                            onGoLive: _liveDvrActive
                                ? _goLive
                                : (_isBehindLive ? _goLiveLocal : null),
                            isBehindLive: _isBehindLive,
                            playPauseFocusNode: _playPauseFocusNode,
                            backFocusNode: _backFocusNode,
                            buffering: _isBuffering &&
                                _retryCount < _maxRetries,
                            onChannels: _isChannelPlayback &&
                                    widget.contentId != null
                                ? _openChannels
                                : null,
                          ),
                        ),
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
                  onDismiss: () => setState(() => _showUpNext = false),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ep = widget.episode;
    final still = ep.stillUrl;
    return Positioned(
      bottom: 32,
      right: 32,
      child: Material(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        elevation: 6,
        child: SizedBox(
          width: 340,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (still != null && still.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    still,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        ColoredBox(color: scheme.surfaceContainerHighest),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Up next',
                        style: theme.textTheme.labelLarge!
                            .copyWith(color: scheme.primary)),
                    const SizedBox(height: 4),
                    Text(
                      '${ep.episodeLabel} · ${ep.displayTitle}',
                      style: theme.textTheme.titleMedium!
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TvActivatable(
                            autofocus: true,
                            onTap: widget.onPlay,
                            builder: (onTap) => FilledButton.icon(
                              onPressed: onTap,
                              style: FilledButton.styleFrom(
                                  shape: const StadiumBorder(),
                                  minimumSize: const Size.fromHeight(44)),
                              icon: SizedBox(
                                width: 20,
                                height: 20,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: 1 - _remaining / _totalSeconds,
                                      strokeWidth: 2.2,
                                      color: scheme.onPrimary,
                                      backgroundColor: scheme.onPrimary
                                          .withValues(alpha: 0.3),
                                    ),
                                    Text('$_remaining',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: scheme.onPrimary)),
                                  ],
                                ),
                              ),
                              label: const Text('Play now'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TvActivatable(
                          onTap: widget.onDismiss,
                          builder: (onTap) => TextButton(
                            onPressed: onTap,
                            child: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.title, this.status, this.visible = true});

  final bool visible;
  final String title;
  // e.g. "Reconnecting… (2 of 5)"; the title alone while first loading.
  final String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 52,
          height: 52,
          child: ProgressIndicatorTheme(
            data:
                ProgressIndicatorTheme.of(context).copyWith(year2023: false),
            child: CircularProgressIndicator(
              strokeWidth: 5,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            context.displayName(title),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium!.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (status != null) ...[
          const SizedBox(height: 6),
          Text(status!,
              style: theme.textTheme.bodyMedium!
                  .copyWith(color: Colors.white60)),
        ],
      ],
      ),
    );
  }
}

final _outlined = OutlinedButton.styleFrom(
  shape: const StadiumBorder(),
  foregroundColor: Colors.white,
  side: const BorderSide(color: Colors.white38),
);

class _ErrorOverlay extends StatefulWidget {
  const _ErrorOverlay({
    required this.title,
    required this.onRetry,
    required this.onBack,
    this.onChannels,
    this.message,
  });

  final String title;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  // Live TV: pick another channel straight from the error screen.
  final VoidCallback? onChannels;
  // Specific reason when known; otherwise a generic message.
  final String? message;

  @override
  State<_ErrorOverlay> createState() => _ErrorOverlayState();
}

class _ErrorOverlayState extends State<_ErrorOverlay> {
  // The player surface already holds focus, so plain autofocus loses; claim
  // it explicitly so a TV remote lands on Try again.
  final _retryFocus = FocusNode(debugLabel: 'PlayerRetry');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _retryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _retryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = theme.colorScheme.error;
    final message = widget.message;
    final title = widget.title;
    final onRetry = widget.onRetry;
    final onBack = widget.onBack;
    final onChannels = widget.onChannels;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: error.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, color: error, size: 38),
            ),
            const SizedBox(height: 18),
            Text(
              message ?? "This stream isn't playing right now",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge!.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              context.displayName(title),
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodyMedium!.copyWith(color: Colors.white60),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                TvActivatable(
                  focusNode: _retryFocus,
                  onTap: onRetry,
                  builder: (onTap) => FilledButton.icon(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(shape: const StadiumBorder()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Try again'),
                  ),
                ),
                if (onChannels != null)
                  TvActivatable(
                    onTap: onChannels,
                    builder: (onTap) => OutlinedButton.icon(
                      onPressed: onTap,
                      style: _outlined,
                      icon: const Icon(Icons.format_list_bulleted_rounded),
                      label: const Text('Channels'),
                    ),
                  ),
                TvActivatable(
                  onTap: onBack,
                  builder: (onTap) => OutlinedButton.icon(
                    onPressed: onTap,
                    style: _outlined,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Go back'),
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
