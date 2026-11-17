import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Fake TV snow for the Retro Cable look (#178): shown while a channel is
/// tuning, like an old set between stations. A handful of tiny noise bitmaps
/// are made once (shared by every use) and flipped through, scaled up
/// without smoothing so the grains stay chunky; a dark band rolls down the
/// screen. Costs next to nothing per frame.
class StaticNoise extends StatefulWidget {
  const StaticNoise({super.key});

  @override
  State<StaticNoise> createState() => _StaticNoiseState();
}

const _w = 160;
const _h = 90;
const _frameCount = 8;

Future<List<ui.Image>>? _frames;

Future<List<ui.Image>> _makeFrames() {
  final rnd = math.Random(7);
  return Future.wait([
    for (var f = 0; f < _frameCount; f++)
      () {
        final px = Uint8List(_w * _h * 4);
        for (var i = 0; i < _w * _h; i++) {
          // Mid-to-bright greys, never full white: easier on the eyes.
          final v = 30 + rnd.nextInt(170);
          px[i * 4] = v;
          px[i * 4 + 1] = v;
          px[i * 4 + 2] = v;
          px[i * 4 + 3] = 255;
        }
        final c = Completer<ui.Image>();
        ui.decodeImageFromPixels(px, _w, _h, ui.PixelFormat.rgba8888, c.complete);
        return c.future;
      }(),
  ]);
}

class _StaticNoiseState extends State<StaticNoise>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _tick = ValueNotifier<int>(0);
  List<ui.Image>? _ready;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _frames ??= _makeFrames();
    _frames!.then((v) {
      if (mounted) setState(() => _ready = v);
    });
    _ticker = createTicker((d) {
      // About 15 flips a second.
      if ((d - _last).inMilliseconds >= 66) {
        _last = d;
        _tick.value++;
      }
    });
    if (!WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frames = _ready;
    if (frames == null) return const ColoredBox(color: Color(0xFF202020));
    return RepaintBoundary(
      child: CustomPaint(
        painter: _NoisePainter(frames, _tick),
        size: Size.infinite,
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  _NoisePainter(this.frames, this.tick) : super(repaint: tick);

  final List<ui.Image> frames;
  final ValueNotifier<int> tick;

  @override
  void paint(Canvas canvas, Size size) {
    final n = tick.value;
    final img = frames[n % frames.length];
    final rect = Offset.zero & size;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, _w.toDouble(), _h.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.none,
    );
    // A dark rolling band, slowly down the picture.
    final bandH = size.height * 0.18;
    final y = ((n * 0.011) % 1.4 - 0.2) * size.height;
    canvas.drawRect(
      Rect.fromLTWH(0, y, size.width, bandH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y),
          Offset(0, y + bandH),
          const [Color(0x00000000), Color(0x66000000), Color(0x00000000)],
          const [0, 0.5, 1],
        ),
    );
    // Dim it all a touch.
    canvas.drawRect(rect, Paint()..color = const Color(0x40000000));
  }

  @override
  bool shouldRepaint(_NoisePainter old) => false;
}
