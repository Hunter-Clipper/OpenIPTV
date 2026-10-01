import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:open_iptv/shared/widgets/poster_image.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

/// One poster in a [MediaRail].
class RailItem {
  const RailItem({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.imageUrl,
    this.progress,
    this.watched = false,
    this.onLongPress,
    this.heroTag,
    this.locked = false,
    this.highlightSubtitle = false,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  // 0..1 — shown as a bar under the poster (Continue Watching).
  final double? progress;
  final bool watched;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  // Poster flies to the detail page's poster with the same tag.
  final Object? heroTag;
  // Behind the parental PIN: a small lock badge on the card.
  final bool locked;
  // Subtitle in the accent colour (e.g. a channel's programme on now).
  final bool highlightSubtitle;
}

/// Card shape of a [MediaRail]: 2:3 artwork posters, or 16:9 tiles with a
/// channel logo centred on [logoTileColors].
enum RailShape { poster, logo }

/// Mid-grey, lighter than the page: dark logos (A&E, Adult Swim) vanish on
/// the usual surface colours, and white ones would on anything paler.
const logoTileColors = [Color(0xFF4A4A50), Color(0xFF36363B)];

/// Poster sizes for rails: larger on TV (viewed from the sofa).
double railPosterWidth(BuildContext context) =>
    PlatformHelper.isTV(context) ? 150 : 118;

/// A titled, horizontally scrolling row of posters — the building block of
/// the Movies and Series home screens.
class MediaRail extends StatelessWidget {
  const MediaRail({
    super.key,
    required this.title,
    required this.items,
    this.onSeeAll,
    this.onHeaderLongPress,
    this.locked = false,
    this.autofocusFirst = false,
    this.fallbackIcon = Icons.movie_outlined,
    this.shape = RailShape.poster,
    this.count,
  });

  final String title;
  final List<RailItem> items;
  final VoidCallback? onSeeAll;
  // Long-press on "See all" — e.g. the Hide Genre sheet.
  final VoidCallback? onHeaderLongPress;
  // Parental-locked genre: shows a lock beside the title.
  final bool locked;
  final bool autofocusFirst;
  final IconData fallbackIcon;
  final RailShape shape;
  // Shown muted after the title (e.g. the number of search matches).
  final int? count;

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformHelper.isTV(context);
    final width = shape == RailShape.logo
        ? (isTV ? 220.0 : 176.0)
        : railPosterWidth(context);
    final posterHeight = shape == RailShape.logo ? width * 9 / 16 : width * 1.5;
    final hasSubtitle = items.any((i) => i.subtitle != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RailHeader(
          title: title,
          onSeeAll: onSeeAll,
          onLongPress: onHeaderLongPress,
          locked: locked,
          count: count,
        ),
        SizedBox(
          // Poster + padding + title (+ subtitle) lines.
          height: posterHeight + 40 + (hasSubtitle ? 16 : 0),
          child: TvRowFocus(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              clipBehavior: Clip.none,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _PosterCard(
                item: items[i],
                width: width,
                height: posterHeight,
                shape: shape,
                autofocus: autofocusFirst && i == 0,
                fallbackIcon: fallbackIcon,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Section title with an optional "See all" action.
class RailHeader extends StatelessWidget {
  const RailHeader({
    super.key,
    required this.title,
    this.onSeeAll,
    this.onLongPress,
    this.locked = false,
    this.count,
  });

  final String title;
  final VoidCallback? onSeeAll;
  final VoidCallback? onLongPress;
  final bool locked;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 2),
      child: Row(
        children: [
          if (locked) ...[
            Icon(Icons.lock_outline,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          // Title (+ count) takes the free width, keeping "See all" flush
          // right; a Flexible + Spacer pair split it and pulled it inwards.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium!
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 17),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 8),
                  Text('$count',
                      style: theme.textTheme.titleSmall!
                          .copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            TvActivatable(
              onTap: onSeeAll,
              builder: (onTap) => TextButton(
                onPressed: onTap,
                onLongPress: onLongPress,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  foregroundColor: theme.colorScheme.primary,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('See all'),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PosterCard extends StatefulWidget {
  const _PosterCard({
    required this.item,
    required this.width,
    required this.height,
    required this.shape,
    required this.autofocus,
    required this.fallbackIcon,
  });

  final RailItem item;
  final double width;
  final double height;
  final RailShape shape;
  final bool autofocus;
  final IconData fallbackIcon;

  @override
  State<_PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<_PosterCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    // Focus lift only on TV (touch devices would otherwise show the last
    // tapped card as permanently raised).
    final lit = _focused && PlatformHelper.isTV(context);
    final radius = BorderRadius.circular(12);
    return TvFocusable(
      onTap: item.onTap,
      onLongPress: item.onLongPress,
      autofocus: widget.autofocus,
      ensureVisibleOnFocus: true,
      showFocusRing: false,
      onFocusChange: (f) => setState(() => _focused = f),
      child: SizedBox(
        width: widget.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedScale(
              scale: lit ? 1.07 : 1.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: widget.shape == RailShape.logo
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: logoTileColors,
                        )
                      : null,
                  border: Border.all(
                    color: lit ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: lit
                          ? theme.colorScheme.primary.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.35),
                      blurRadius: lit ? 18 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _maybeHero(
                  item.heroTag,
                  ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.shape == RailShape.logo)
                          _Logo(
                              url: item.imageUrl, icon: widget.fallbackIcon)
                        else
                          PosterImage(
                            posterUrl: item.imageUrl,
                            iconSize: 30,
                            fallbackIcon: widget.fallbackIcon,
                          ),
                        if (item.locked)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.lock_rounded,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        if (item.watched)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_circle,
                                  color: Colors.white, size: 15),
                            ),
                          ),
                        if (item.progress != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(
                              value: item.progress!.clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium!
                  .copyWith(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            if (item.subtitle != null)
              Text(
                item.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall!.copyWith(
                  fontSize: 11.5,
                  color: item.highlightSubtitle
                      ? theme.colorScheme.primary
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Rail for a parental-locked genre: no artwork until unlocked, just a lock
/// card that asks for the PIN (as does "See all").
class LockedRail extends StatelessWidget {
  const LockedRail({
    super.key,
    required this.title,
    required this.onUnlock,
    this.onHeaderLongPress,
    this.autofocusFirst = false,
  });

  final String title;
  final VoidCallback onUnlock;
  final VoidCallback? onHeaderLongPress;
  final bool autofocusFirst;

  @override
  Widget build(BuildContext context) {
    return MediaRail(
      title: title,
      locked: true,
      onSeeAll: onUnlock,
      onHeaderLongPress: onHeaderLongPress,
      autofocusFirst: autofocusFirst,
      fallbackIcon: Icons.lock_outline,
      items: [RailItem(title: 'Enter PIN to view', onTap: onUnlock)],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.url, required this.icon});

  final String? url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(icon,
        size: 36, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: url == null || url!.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.contain,
              memCacheWidth: 300,
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}

Widget _maybeHero(Object? tag, Widget child) =>
    tag == null ? child : Hero(tag: tag, child: child);
