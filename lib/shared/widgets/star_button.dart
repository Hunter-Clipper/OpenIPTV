import 'package:flutter/material.dart';

/// Standardized small circular favorite-toggle overlay used on poster/grid
/// thumbnails (as opposed to the plain [IconButton] favorite toggle used in
/// app bars and detail screens). Always uses the theme's accent color for
/// the active state, so it matches whatever accent color the user picked
/// instead of a hardcoded hue.
class StarButton extends StatelessWidget {
  const StarButton({super.key, required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isFavorite ? Icons.star : Icons.star_border,
          size: 18,
          color: isFavorite
              ? Theme.of(context).colorScheme.primary
              : Colors.white70,
        ),
      ),
    );
  }
}
