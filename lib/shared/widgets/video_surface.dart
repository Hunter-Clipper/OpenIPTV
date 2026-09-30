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
    this.fit = 'fit',
  });

  final int textureId;
  /// 'fit' letterboxes the whole picture (never distorted); 'fill' crops it
  /// to cover the screen; 'zoom' is between the two. Aspect ratio is always
  /// kept — the picture is never stretched.
  final String fit;
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
    final fitted = Center(child: AspectRatio(aspectRatio: ar, child: texture));
    return LayoutBuilder(builder: (context, c) {
      final screenAr = c.maxWidth / c.maxHeight;
      // Scale that makes the fitted picture cover the whole screen.
      final cover = ar > screenAr ? ar / screenAr : screenAr / ar;
      final scale = switch (widget.fit) {
        'fill' => cover,
        'zoom' => 1 + (cover - 1) / 2,
        _ => 1.0,
      };
      return ClipRect(
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: fitted,
        ),
      );
    });
  }
}
