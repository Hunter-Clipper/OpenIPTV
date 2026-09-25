import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_iptv/core/services/native_video_player.dart';

/// Renders a native video texture at the content's own aspect ratio,
/// letterboxed/pillarboxed inside whatever space it's given — a bare
/// [Texture] stretches to fill its parent, distorting the picture.
///
/// Listens to [stateStream] itself and rebuilds only when the aspect ratio
/// changes, not on every 500ms position tick.
class VideoSurface extends StatefulWidget {
  const VideoSurface({
    super.key,
    required this.textureId,
    required this.stateStream,
    this.initialAspectRatio,
  });

  final int textureId;
  final Stream<NativeVideoPlayerState> stateStream;
  final double? initialAspectRatio;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  double? _aspectRatio;
  StreamSubscription<NativeVideoPlayerState>? _sub;

  @override
  void initState() {
    super.initState();
    _aspectRatio = widget.initialAspectRatio;
    _subscribe();
  }

  @override
  void didUpdateWidget(VideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stateStream != widget.stateStream) {
      _sub?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    _sub = widget.stateStream.listen((s) {
      final ar = s.aspectRatio;
      if (ar != null && ar != _aspectRatio) setState(() => _aspectRatio = ar);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texture = Texture(textureId: widget.textureId);
    final ar = _aspectRatio;
    // Before the first frame the size is unknown; nothing is visible yet,
    // so filling is harmless.
    if (ar == null) return texture;
    return Center(child: AspectRatio(aspectRatio: ar, child: texture));
  }
}
