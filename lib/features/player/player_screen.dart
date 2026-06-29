import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
  });

  final String streamUrl;
  final String title;
  final String? contentId;
  final String? contentType;
  final Duration? resumePosition;

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
      if (mounted) setState(() => _isBuffering = buffering);
    });
    _videoParamsSub = player.stream.videoParams.listen((vp) {
      if ((vp.w ?? 0) > 0 && mounted) {
        setState(() => _isBuffering = false);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPlayback();
    });

    _resetHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _bufferingSub?.cancel();
    _videoParamsSub?.cancel();
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
      _playbackService.db.updateChannelLastWatched(widget.contentId!);
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

  Future<bool> _showResumeDialog(Duration position) async {
    final result = await showDialog<bool>(
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
    return result ?? true;
  }

  void _saveProgressIfNeeded() {
    if (_isLive) return;
    final id = widget.contentId;
    if (id == null) return;
    final service = _playbackService;
    final pos = service.player.state.position;
    final total = service.player.state.duration;
    debugPrint('[OTV-save] type=${widget.contentType} id=$id pos=${pos.inSeconds}s total=${total.inSeconds}s');
    if (widget.contentType == 'movie') {
      service.saveMovieProgress(id, total);
    } else if (widget.contentType == 'episode') {
      service.saveEpisodeProgress(id, total);
    }
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
            // Buffering overlay — hides corrupt decoder-warmup frames and
            // shows a spinner while the stream is loading/rebuffering.
            AnimatedOpacity(
              opacity: _isBuffering ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !_isBuffering,
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          widget.title,
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
          ],
        ),
      ),
    );
  }
}
