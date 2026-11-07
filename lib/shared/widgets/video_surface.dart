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
/// How far the picture's zoom has got (0 = still on the lower screen's
/// rectangle, 1 = settled). Screens drawn over the picture fade in with it.
final ValueNotifier<double> videoZoomProgress = ValueNotifier<double>(1);

/// Fades [child] in with the picture's zoom, so controls don't sit over the
/// guide before the picture has grown.
class ZoomFade extends StatelessWidget {
  const ZoomFade({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
        valueListenable: videoZoomProgress,
        builder: (context, t, child) => t >= 1
            ? child!
            : Opacity(opacity: ((t - 0.4) / 0.6).clamp(0.0, 1.0), child: child),
        child: child,
      );
}

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

class _VideoSurfaceState extends State<VideoSurface>
    with SingleTickerProviderStateMixin {
  // Layer users (the guide's pane, the full-screen player) can both be
  // mounted at once, one route above the other: the newest one owns the
  // layer, and the one below takes it back when the top one goes away.
  static final List<_VideoSurfaceState> _layerUsers = [];
  double _lastScale = 1;
  double? _lastAr;
  double? _aspectRatio;
  StreamSubscription<NativeVideoPlayerState>? _sub;
  // The route's open/close animation, when this picture sits on a route
  // that opens over another layer user (the guide's pane): the picture then
  // grows from the pane's rectangle to full screen, and shrinks back.
  Animation<double>? _routeAnim;
  // Drives the zoom out of the lower user's rectangle. It starts a moment
  // after the screen's first frames: the route's own clock keeps running
  // while a heavy first build blocks frames, which skipped most of the
  // zoom. The route's animation still drives the zoom back (on closing).
  late final AnimationController _open =
      AnimationController(
          vsync: this, duration: motionDuration(const Duration(milliseconds: 320)));

  @override
  void initState() {
    super.initState();
    _aspectRatio = widget.initialAspectRatio;
    _subscribe();
    if (widget.useLayer) {
      _layerUsers.add(this);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Two settled frames, then zoom.
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (mounted) _open.forward();
        });
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeAnim = widget.useLayer ? ModalRoute.of(context)?.animation : null;
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
    if (widget.useLayer) {
      // Whatever was fading with this picture is settled (or gone).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (videoZoomProgress.value != 1) videoZoomProgress.value = 1;
      });
    }
    _open.dispose();
    _sub?.cancel();
    if (widget.useLayer) {
      final wasTop = _layerUsers.isNotEmpty && _layerUsers.last == this;
      _layerUsers.remove(this);
      if (wasTop) {
        if (_layerUsers.isNotEmpty) {
          _layerUsers.last._sentRect = null;
        } else {
          NativeVideoPlayer.setVideoLayer(widget.textureId, null);
        }
      }
    }
    super.dispose();
  }

  // Tells the native layer where the picture goes, in pixels. The rect is
  // re-read every frame while this screen owns the layer, so it follows the
  // picture when the guide's pane moves or resizes (no rebuild needed).
  List<int>? _sentRect;
  bool _pumping = false;

  void _reportLayer(double scale, double? ar) {
    _lastScale = scale;
    _lastAr = ar;
    _sentRect = null; // new layout: send even if the numbers match
    _pump();
  }

  void _pump() {
    if (_pumping) return;
    _pumping = true;
    void tick(Duration _) {
      if (!mounted) {
        _pumping = false;
        return;
      }
      final top = _layerUsers.isEmpty || _layerUsers.last == this;
      final box = context.findRenderObject();
      if (top && box is RenderBox && box.hasSize && box.attached) {
        final rect = _rectOf(box);
        if (_sentRect == null || !_listEq(rect, _sentRect!)) {
          _sentRect = rect;
          NativeVideoPlayer.setVideoLayer(widget.textureId, rect);
        }
      }
      WidgetsBinding.instance.addPostFrameCallback(tick);
      // Frames only run while something changes; ask for one so a pane that
      // moves with no rebuild is still noticed.
    }

    WidgetsBinding.instance.addPostFrameCallback(tick);
  }

  // The user below this one on the layer stack (the guide's pane under the
  // player), if any, and its picture rectangle in logical pixels.
  Rect? _lowerRect() {
    final i = _layerUsers.indexOf(this);
    if (i <= 0) return null;
    final lower = _layerUsers[i - 1];
    if (!lower.mounted) return null;
    final box = lower.context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    return lower._pictureRect(box);
  }

  /// 0 = the lower user's rectangle, 1 = this one's; follows the route.
  double get _openness {
    if (_lowerRectCache == null) return 1;
    return _eased();
  }

  Rect? _lowerRectCache;

  double _eased() {
    final r = _routeAnim?.value ?? 1.0;
    final v = r < _open.value ? r : _open.value;
    return Curves.easeInOutCubic.transform(v.clamp(0.0, 1.0));
  }

  /// Where the picture sits inside [box], in logical pixels on the screen.
  Rect _pictureRect(RenderBox box) {
    final origin = box.localToGlobal(Offset.zero);
    final size = box.size;
    final ar = _lastAr;
    final screenAr = size.width / size.height;
    var w = ar == null || ar > screenAr ? size.width : size.height * ar;
    var h = ar == null || ar > screenAr
        ? size.width / (ar ?? screenAr)
        : size.height;
    w *= _lastScale;
    h *= _lastScale;
    return Rect.fromCenter(
        center: origin + Offset(size.width / 2, size.height / 2),
        width: w,
        height: h);
  }

  List<int> _rectOf(RenderBox box) {
    var r = _pictureRect(box);
    _lowerRectCache = _lowerRect();
    final low = _lowerRectCache;
    final t = _openness;
    if (low != null && t < 1) r = Rect.lerp(low, r, t)!;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return [
      (r.left * dpr).round(),
      (r.top * dpr).round(),
      (r.width * dpr).round(),
      (r.height * dpr).round(),
    ];
  }

  static bool _listEq(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final texture = Texture(textureId: widget.textureId);
    final ar = _aspectRatio;
    // Size unknown (no frame yet, or a new stream opening): nothing to show.
    if (ar == null) {
      if (!widget.useLayer) return const SizedBox.expand();
      // Nothing to show yet, but the layer must exist from the start so the
      // picture never has to switch surfaces (which restarts the stream).
      _reportLayer(1, null);
      return const ColoredBox(color: Colors.black, child: SizedBox.expand());
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
        // layer behind Flutter shows through. While the route opens or
        // closes over another layer user, the area grows from that user's
        // rectangle and the black fades in, so the guide stays visible
        // around a picture that zooms.
        var w = ar > screenAr ? c.maxWidth : c.maxHeight * ar;
        var h = ar > screenAr ? c.maxWidth / ar : c.maxHeight;
        w *= scale;
        h *= scale;
        final to = Rect.fromCenter(
            center: Offset(c.maxWidth / 2, c.maxHeight / 2),
            width: w,
            height: h);
        return AnimatedBuilder(
          animation: Listenable.merge([_routeAnim, _open]),
          builder: (context, _) {
            final low = _lowerRect();
            final t = low == null ? 1.0 : _eased();
            if (_layerUsers.isNotEmpty && _layerUsers.last == this) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (videoZoomProgress.value != t) videoZoomProgress.value = t;
              });
            }
            var hole = to;
            if (low != null && t < 1) {
              final box = context.findRenderObject();
              final origin = box is RenderBox && box.hasSize && box.attached
                  ? box.localToGlobal(Offset.zero)
                  : Offset.zero;
              hole = Rect.lerp(low.shift(-origin), to, t)!;
            }
            return CustomPaint(
                size: Size(c.maxWidth, c.maxHeight),
                painter: _HolePainter(hole, t));
          },
        );
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
  _HolePainter(this.hole, [this.blackness = 1]);
  final Rect hole;
  final double blackness;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
        Paint()..color = Colors.black.withValues(alpha: blackness));
    // Clears everything painted so far under the picture (even the guide's
    // own background), so the video layer behind Flutter shows through.
    canvas.drawRect(hole, Paint()..blendMode = BlendMode.clear);
  }

  @override
  bool shouldRepaint(_HolePainter old) =>
      old.hole != hole || old.blackness != blackness;
}
