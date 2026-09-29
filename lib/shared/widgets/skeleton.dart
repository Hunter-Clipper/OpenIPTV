import 'package:flutter/material.dart';

/// Loading placeholder shaped like the list that's about to appear — rows of
/// softly shimmering blocks instead of a spinner, so the layout doesn't jump
/// when the content arrives.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 10, this.leadingSize = 40});

  final int itemCount;
  // Width/height of each row's leading block (icon, logo or thumbnail).
  final double leadingSize;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: itemCount,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _Block(width: leadingSize, height: leadingSize, radius: 10),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Varying widths read as text rather than bars.
                    FractionallySizedBox(
                      widthFactor: const [0.62, 0.48, 0.7, 0.55][i % 4],
                      child: const _Block(height: 14),
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: const [0.34, 0.4, 0.28, 0.38][i % 4],
                      child: const _Block(height: 10),
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

class _Block extends StatelessWidget {
  const _Block({this.width, required this.height, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Paints [child]'s shapes with a slow light sweep — the standard
/// "skeleton" loading shimmer.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Color.lerp(base, Colors.white, 0.08)!;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.0 + 3 * t - 1, -0.3),
            end: Alignment(1.0 + 3 * t - 1, 0.3),
            colors: [base, highlight, base],
            stops: const [0.35, 0.5, 0.65],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
