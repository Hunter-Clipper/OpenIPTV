import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  late VideoController _videoController;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _resumeDialogShown = false;

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

    final service = ref.read(playbackServiceProvider);
    _videoController = VideoController(service.player);

    // Start playback after first frame so the dialog can show if needed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPlayback();
    });

    _resetHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Save progress then stop — order matters so position is captured first.
    _saveProgressIfNeeded();
    ref.read(playbackServiceProvider).stop();
    super.dispose();
  }

  Future<void> _startPlayback() async {
    final service = ref.read(playbackServiceProvider);

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
    final service = ref.read(playbackServiceProvider);
    final total = service.player.state.duration;
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
            // Video
            Video(controller: _videoController),
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
