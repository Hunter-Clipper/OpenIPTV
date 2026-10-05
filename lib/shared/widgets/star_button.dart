import 'package:flutter/material.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

/// Standardized small circular favorite-toggle overlay used on poster/grid
/// thumbnails (as opposed to the plain [IconButton] favorite toggle used in
/// app bars and detail screens). Always uses the theme's accent color for
/// the active state, so it matches whatever accent color the user picked
/// instead of a hardcoded hue.
///
/// On TV it is only a marker (favourites only, never a focus stop): as a
/// separate stop inside the card, the D-pad landed on the star before the
/// card itself (#31). Remote users hold OK on the card instead — every
/// card's long-press sheet has Add to / Remove from Favorites.
class StarButton extends StatelessWidget {
  const StarButton({super.key, required this.isFavorite, required this.onTap});

  final bool isFavorite;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tv = PlatformHelper.isTV(context);
    if (tv && !isFavorite) return const SizedBox.shrink();
    final content = Container(
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
    );
    if (onTap == null || tv) return content;
    return TvFocusable(
      onTap: onTap!,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}
