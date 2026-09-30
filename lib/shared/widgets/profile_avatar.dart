import 'package:flutter/material.dart';

/// A profile's emoji on a round, softly tinted background. The tint is
/// picked from the profile's name, so each profile keeps its own colour
/// everywhere it appears (picker, Settings, profile management).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.emoji,
    required this.name,
    this.size = 44,
    this.highlighted = false,
  });

  final String emoji;
  final String name;
  final double size;
  // TV focus: white ring and a coloured glow.
  final bool highlighted;

  static const _palette = [
    Color(0xFF3D5AFE),
    Color(0xFF00897B),
    Color(0xFFF4511E),
    Color(0xFF8E24AA),
    Color(0xFF43A047),
    Color(0xFFD81B60),
    Color(0xFF1E88E5),
    Color(0xFFFFB300),
  ];

  static Color colorFor(String name) =>
      _palette[name.codeUnits.fold(0, (a, c) => a + c) % _palette.length];

  @override
  Widget build(BuildContext context) {
    final color = colorFor(name);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.25),
          ],
        ),
        border: Border.all(
          color: highlighted ? Colors.white : Colors.transparent,
          width: size > 60 ? 3 : 2,
        ),
        boxShadow: size > 60
            ? [
                BoxShadow(
                  color: highlighted
                      ? color.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.3),
                  blurRadius: highlighted ? 24 : 10,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}
