import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_iptv/shared/utils/motion.dart';
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
    this.useLayer = false,
  });

  /// Show the picture on the real video layer behind Flutter (#162) instead
  /// of the texture. The area stays empty (see-through) in Flutter.
  final bool useLayer;

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
      // A stream that has no picture yet (a new one just opened) clears the
      // old ratio, so the previous stream's last frame isn't drawn in the
      // wrong shape.
      if (ar == _aspectRatio) return;
      setState(() => _aspectRatio = ar);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (widget.useLayer) NativeVideoPlayer.setVideoLayer(widget.textureId, null);
    super.dispose();
  }

  // Tells the native layer where the picture goes, in pixels.
  void _reportLayer(double scale, double ar) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final origin = box.localToGlobal(Offset.zero);
      final size = box.size;
      final screenAr = size.width / size.height;
      var w = ar > screenAr ? size.width : size.height * ar;
      var h = ar > screenAr ? size.width / ar : size.height;
      w *= scale;
      h *= scale;
      final cx = origin.dx + size.width / 2;
      final cy = origin.dy + size.height / 2;
      final dpr = MediaQuery.devicePixelRatioOf(context);
      NativeVideoPlayer.setVideoLayer(widget.textureId, [
        ((cx - w / 2) * dpr).round(),
        ((cy - h / 2) * dpr).round(),
        (w * dpr).round(),
        (h * dpr).round(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final texture = Texture(textureId: widget.textureId);
    final ar = _aspectRatio;
    // Size unknown (no frame yet, or a new stream opening): nothing to show.
    if (ar == null) {
      return widget.useLayer
          ? const ColoredBox(color: Colors.black, child: SizedBox.expand())
          : const SizedBox.expand();
    }
    if (widget.useLayer) {
      return LayoutBuilder(builder: (context, c) {
        final screenAr = c.maxWidth / c.maxHeight;
        final cover = ar > screenAr ? ar / screenAr : screenAr / ar;
        final scale = switch (widget.fit) {
          'fill' => cover,
          'zoom' => 1 + (cover - 1) / 2,
          _ => 1.0,
        };
        _reportLayer(scale, ar);
        // Black everywhere except the picture's own area, where the video
        // layer behind Flutter shows through.
        var w = ar > screenAr ? c.maxWidth : c.maxHeight * ar;
        var h = ar > screenAr ? c.maxWidth / ar : c.maxHeight;
        w *= scale;
        h *= scale;
        final hole = Rect.fromCenter(
            center: Offset(c.maxWidth / 2, c.maxHeight / 2), width: w, height: h);
        return CustomPaint(
            size: Size(c.maxWidth, c.maxHeight), painter: _HolePainter(hole));
      });
    }
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
          duration: motionDuration(const Duration(milliseconds: 220)),
          curve: Curves.easeOutCubic,
          child: fitted,
        ),
      );
    });
  }
}

/// Paints black around [hole] and leaves it see-through.
class _HolePainter extends CustomPainter {
  _HolePainter(this.hole);
  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRect(hole),
    );
    canvas.drawPath(path, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.hole != hole;
}
