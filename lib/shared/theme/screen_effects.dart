import 'package:flutter/material.dart';

/// How dark the scan lines are.
enum CrtStrength {
  light(id: 'light', alpha: 0.12),
  medium(id: 'medium', alpha: 0.22),
  strong(id: 'strong', alpha: 0.34);

  const CrtStrength({required this.id, required this.alpha});

  final String id;

  /// Opacity of the black line.
  final double alpha;

  static CrtStrength fromId(String? id) => values
      .firstWhere((s) => s.id == id, orElse: () => CrtStrength.medium);
}

/// The old-TV look drawn over the whole app (#178), switched on and off
/// piece by piece. Everything is off by default.
@immutable
class ScreenEffects {
  const ScreenEffects({
    this.lines = false,
    this.strength = CrtStrength.medium,
    this.glow = false,
  });

  /// Horizontal scan lines.
  final bool lines;
  final CrtStrength strength;

  /// A soft dark vignette with a faint warm centre.
  final bool glow;

  bool get any => lines || glow;

  ScreenEffects copyWith({bool? lines, CrtStrength? strength, bool? glow}) =>
      ScreenEffects(
        lines: lines ?? this.lines,
        strength: strength ?? this.strength,
        glow: glow ?? this.glow,
      );

  @override
  bool operator ==(Object other) =>
      other is ScreenEffects &&
      other.lines == lines &&
      other.strength == strength &&
      other.glow == glow;

  @override
  int get hashCode => Object.hash(lines, strength, glow);
}

/// Draws [child] with the [effects] over it. The overlay ignores touches and
/// the remote, and is drawn as one cheap gradient rectangle per effect in its
/// own layer, so it costs next to nothing per frame.
class ScreenEffectsOverlay extends StatelessWidget {
  const ScreenEffectsOverlay({
    super.key,
    required this.effects,
    required this.child,
  });

  final ScreenEffects effects;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!effects.any) return child;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (effects.glow) const _Vignette(),
                    if (effects.lines)
                      CustomPaint(
                        painter: _ScanLines(effects.strength.alpha, dpr),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One dark line in every three physical pixels, as a single repeating
/// gradient (so the whole screen is one rectangle to draw).
class _ScanLines extends CustomPainter {
  const _ScanLines(this.alpha, this.dpr);

  final double alpha;
  final double dpr;

  @override
  void paint(Canvas canvas, Size size) {
    final period = 3 / dpr;
    final line = Color.fromRGBO(0, 0, 0, alpha);
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [line, line, Colors.transparent, Colors.transparent],
      stops: const [0, 1 / 3, 1 / 3, 1],
      tileMode: TileMode.repeated,
    ).createShader(Rect.fromLTWH(0, 0, size.width, period));
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ScanLines old) => old.alpha != alpha || old.dpr != dpr;
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 1.05,
            colors: [
              Color(0x0AFFE2B0), // faint warm centre
              Color(0x00000000),
              Color(0x59000000), // darker corners
            ],
            stops: [0, 0.6, 1],
          ),
        ),
      );
}
