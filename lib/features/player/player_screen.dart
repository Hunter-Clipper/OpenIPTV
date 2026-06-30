import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:open_iptv/core/models/episode.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/features/player/player_controls.dart';

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
  late final VideoController _videoController;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _resumeDialogShown = false;
  // Start true so the overlay covers corrupt decoder warmup frames.
  bool _isBuffering = true;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription<VideoParams>? _videoParamsSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _completedSub;
  // Tracks the last non-zero position independently of player state, so that
  // reconnection (which temporarily resets state.position to zero) doesn't
  // corrupt the progress save on dispose.
  Duration _lastKnownPosition = Duration.zero;
  Duration _lastKnownDuration = Duration.zero;

  // Set true once completion has been handled to prevent double-firing
  // (both the completed stream and the position-based fallback can fire).
  bool _completionHandled = false;
  // Set true once we've saved 100% progress on natural completion, so that
  // dispose()'s _saveProgressIfNeeded() doesn't overwrite with a stale value.
  bool _completionSaved = false;

  // Up Next state (episodes only).
  Episode? _nextEpisode;
  bool _showUpNext = false;

  // Auto-recovery: stall detection + reconnect.
  static const _stallTimeout = Duration(seconds: 5);
  static const _maxRetries = 5;
  int _retryCount = 0;
  bool _isRecovering = false;
  Timer? _stallTimer;

  bool get _isLive =>
      widget.contentType == 'live' || widget.contentType == null;

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
    // Create a fresh VideoController tied to this screen's platform view.
    // Register it with the service as a GC anchor so that mpv's native opener
    // thread can never fire Dart callbacks on a collected object.
    _videoController = VideoController(_playbackService.player);
    _playbackService.attachVideoController(_videoController);

    final player = _playbackService.player;

    // Track buffering state. Overlay stays up until the first real frame
    // arrives (videoParams.w > 0), hiding blocky decoder-warmup artifacts.
    _bufferingSub = player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      setState(() => _isBuffering = buffering);
      if (buffering) {
        _startStallTimer();
      } else {
        _cancelStallTimer();
        _retryCount = 0;
        if (_isRecovering) setState(() => _isRecovering = false);
      }
    });
    _videoParamsSub = player.stream.videoParams.listen((vp) {
      if ((vp.w ?? 0) > 0 && mounted) {
        setState(() => _isBuffering = false);
        _cancelStallTimer();
        _retryCount = 0;
        if (_isRecovering) setState(() => _isRecovering = false);
      }
    });
    // Track the last real position so dispose() can save it reliably even if
    // a reconnection has temporarily reset player.state.position to zero.
    if (!_isLive) {
      _positionSub = player.stream.position.listen((p) {
        if (p > Duration.zero) _lastKnownPosition = p;
        // Fallback: some IPTV VOD servers don't send a clean EOF, so
        // player.stream.completed may never fire. Trigger completion when
        // ≤3 s remain according to the known duration.
        if (!_completionHandled &&
            _lastKnownDuration > Duration.zero &&
            p > Duration.zero) {
          final remaining = _lastKnownDuration - p;
          if (remaining.inSeconds <= 3) {
            _completionHandled = true;
            _onPlaybackCompleted();
          }
        }
      });
      _durationSub = player.stream.duration.listen((d) {
        if (d > Duration.zero) _lastKnownDuration = d;
      });
      _completedSub = player.stream.completed.listen((completed) {
        if (completed && mounted && !_completionHandled) {
          _completionHandled = true;
          _onPlaybackCompleted();
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPlayback();
    });

    _resetHideTimer();
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
    final position = _isLive ? null : _lastKnownPosition;
    await _playbackService.play(widget.streamUrl, startPosition: position);
    // Restart stall timer for the new attempt.
    _startStallTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _stallTimer?.cancel();
    _bufferingSub?.cancel();
    _videoParamsSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    _playbackService.detachVideoController();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _saveProgressIfNeeded();
    _playbackService.stop();
    super.dispose();
  }

  Future<void> _startPlayback() async {
    // Stamp last-watched time for live channels so Recently Watched updates.
    if (_isLive && widget.contentId != null) {
      await _playbackService.db.updateChannelLastWatched(widget.contentId!);
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
      await service.play(
        widget.streamUrl,
        startPosition: resume ? widget.resumePosition : null,
      );
    } else {
      await service.play(
        widget.streamUrl,
        startPosition: widget.resumePosition == Duration.zero
            ? null
            : widget.resumePosition,
      );
    }
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
    // Use _lastKnownPosition (tracked via stream) rather than reading
    // player.state.position directly — the latter can be zero if a reconnection
    // attempt called player.open() and the seek hasn't completed yet.
    final position = _lastKnownPosition;
    // Prefer the stream-tracked duration; fall back to player state.
    final total = _lastKnownDuration > Duration.zero
        ? _lastKnownDuration
        : service.player.state.duration;
    debugPrint('[OTV-save] type=${widget.contentType} id=$id pos=${position.inSeconds}s total=${total.inSeconds}s');
    if (widget.contentType == 'movie') {
      service.saveMovieProgress(id, position, total);
    } else if (widget.contentType == 'episode') {
      service.saveEpisodeProgress(id, position, total);
    }
  }

  Future<void> _onPlaybackCompleted() async {
    if (!mounted) return;
    final id = widget.contentId;
    final total = _lastKnownDuration;

    // Save as fully watched.
    if (id != null && total > Duration.zero) {
      _completionSaved = true;
      if (widget.contentType == 'movie') {
        await _playbackService.saveMovieProgress(id, total, total);
      } else if (widget.contentType == 'episode') {
        await _playbackService.saveEpisodeProgress(id, total, total);
      }
    }
    if (!mounted) return;

    // For episodes: look for the next episode in the series.
    if (widget.contentType == 'episode' && widget.seriesId != null) {
      final episodes =
          await _playbackService.db.getEpisodesForSeries(widget.seriesId!);
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
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _onTap() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _resetHideTimer();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Video(
              controller: _videoController,
              controls: NoVideoControls,
            ),
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
                child: PlayerControls(
                  title: widget.title,
                  contentType: widget.contentType,
                  contentId: widget.contentId,
                  isLive: _isLive,
                  onTap: _onTap,
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
