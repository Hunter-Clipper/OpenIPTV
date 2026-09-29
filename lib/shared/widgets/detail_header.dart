import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/widgets/poster_image.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

/// Building blocks of the movie and series detail pages (Google TV style):
/// a full-width backdrop that collapses into a plain app bar, the poster
/// (a [Hero] from the card that was tapped), a one-line meta row, round
/// action buttons and an expandable synopsis.

/// Hero tag for a poster card, unique per row so the same title in two rows
/// (e.g. Continue Watching and its genre) doesn't clash.
String posterHeroTag(String row, String id) => 'poster:$row:$id';

/// Collapsing header: backdrop (or the poster, blurred, when the provider
/// has no backdrop) with the poster, title and meta row over its bottom
/// edge. [actions] go in the app bar (e.g. the favorite star).
class DetailHeader extends StatelessWidget {
  const DetailHeader({
    super.key,
    required this.title,
    required this.posterUrl,
    this.backdropUrl,
    this.heroTag,
    this.meta = const [],
    this.actions = const [],
    this.fallbackIcon = Icons.movie_outlined,
  });

  final String title;
  final String? posterUrl;
  final String? backdropUrl;
  final String? heroTag;
  final List<String> meta;
  final List<Widget> actions;
  final IconData fallbackIcon;

  static const _posterWidth = 108.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final imageHeight = (size.width * 9 / 16).clamp(200.0, size.height * 0.45);
    // The poster overlaps the backdrop's bottom edge by ~60%.
    final expanded = imageHeight + _posterWidth * 1.5 * 0.4 + 8;
    final bg = theme.scaffoldBackgroundColor;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expanded,
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      leading: const _RoundBackButton(),
      actions: [...actions, const SizedBox(width: 8)],
      flexibleSpace: LayoutBuilder(builder: (context, c) {
        final minH = kToolbarHeight + topPad;
        final t =
            ((c.maxHeight - minH) / (expanded + topPad - minH)).clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: t,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: imageHeight + topPad,
                    child: _Backdrop(
                      backdropUrl: backdropUrl,
                      posterUrl: posterUrl,
                    ),
                  ),
                  // Fade the artwork into the page.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: imageHeight + topPad + 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.25, 0.6, 1],
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                            bg.withValues(alpha: 0.35),
                            bg,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Poster(
                          url: posterUrl,
                          heroTag: heroTag,
                          width: _posterWidth,
                          fallbackIcon: fallbackIcon,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.headlineSmall!.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                              if (meta.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  meta.join('  ·  '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium!.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Collapsed: a plain title next to the back button.
            Positioned(
              left: 64,
              right: 64 + 48.0 * actions.length,
              top: topPad,
              height: kToolbarHeight,
              child: IgnorePointer(
                child: Opacity(
                  opacity: (1 - t * 3).clamp(0.0, 1.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.backdropUrl, required this.posterUrl});

  final String? backdropUrl;
  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.surfaceContainer;
    final url = backdropUrl ?? posterUrl;
    if (url == null || url.isEmpty) return ColoredBox(color: fill);
    final image = CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      alignment: backdropUrl != null ? Alignment.topCenter : Alignment.center,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, __) => ColoredBox(color: fill),
      errorWidget: (_, __, ___) => ColoredBox(color: fill),
    );
    if (backdropUrl != null) return image;
    // No backdrop: a soft, blurred wash of the poster instead.
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Opacity(opacity: 0.7, child: image),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({
    required this.url,
    required this.heroTag,
    required this.width,
    required this.fallbackIcon,
  });

  final String? url;
  final String? heroTag;
  final double width;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    Widget poster = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: PosterImage(
        posterUrl: url,
        width: width,
        height: width / AppTheme.posterAspectRatio,
        iconSize: 36,
        fallbackIcon: fallbackIcon,
      ),
    );
    if (heroTag != null) poster = Hero(tag: heroTag!, child: poster);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: poster,
    );
  }
}

class _RoundBackButton extends StatelessWidget {
  const _RoundBackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: TvActivatable(
        onTap: () => Navigator.of(context).maybePop(),
        builder: (onTap) => IconButton(
          style: IconButton.styleFrom(backgroundColor: Colors.black38),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: onTap,
        ),
      ),
    );
  }
}

/// A round app-bar icon button that stays readable over artwork.
class DetailBarButton extends StatelessWidget {
  const DetailBarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TvActivatable(
      onTap: onTap,
      builder: (onTap) => IconButton(
        style: IconButton.styleFrom(backgroundColor: Colors.black38),
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}

/// Primary pill button (Play / Resume) plus round secondary actions with a
/// label underneath — the YouTube TV / Google TV button language.
class DetailActions extends StatelessWidget {
  const DetailActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryIcon = Icons.play_arrow_rounded,
    this.progress,
    this.secondary = const [],
  });

  final String primaryLabel;
  final IconData primaryIcon;
  final VoidCallback? onPrimary; // null: disabled (e.g. still loading)
  // 0..1: shown under the primary button when resuming.
  final double? progress;
  final List<RoundAction> secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            autofocus: true,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
              textStyle: theme.textTheme.titleMedium!
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            icon: Icon(primaryIcon, size: 28),
            label: Text(primaryLabel,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onPressed: onPrimary,
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress!.clamp(0.0, 1.0),
                  minHeight: 3,
                ),
              ),
            ),
          ],
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: secondary,
            ),
          ],
        ],
      ),
    );
  }
}

class RoundAction extends StatelessWidget {
  const RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  // Highlights the icon (e.g. an already-favorited star).
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TvActivatable(
            onTap: onTap,
            builder: (onTap) => IconButton.filledTonal(
              style: IconButton.styleFrom(
                fixedSize: const Size(52, 52),
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              icon:
                  Icon(icon, color: active ? theme.colorScheme.primary : null),
              tooltip: label,
              onPressed: onTap,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium!
                .copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Synopsis clipped to a few lines with a "More" toggle; plus optional
/// cast / director lines.
class DetailSynopsis extends StatefulWidget {
  const DetailSynopsis({super.key, this.text, this.cast, this.director});

  final String? text;
  final String? cast;
  final String? director;

  @override
  State<DetailSynopsis> createState() => _DetailSynopsisState();
}

class _DetailSynopsisState extends State<DetailSynopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.text;
    final muted = theme.textTheme.bodySmall!
        .copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4);
    if (text == null && widget.cast == null && widget.director == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text != null)
            LayoutBuilder(builder: (context, c) {
              final style = theme.textTheme.bodyMedium!.copyWith(height: 1.45);
              final painter = TextPainter(
                text: TextSpan(text: text, style: style),
                maxLines: 4,
                textDirection: Directionality.of(context),
              )..layout(maxWidth: c.maxWidth);
              final overflows = painter.didExceedMaxLines;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: Text(
                      text,
                      style: style,
                      maxLines: _expanded ? null : 4,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                  if (overflows)
                    TvActivatable(
                      onTap: () => setState(() => _expanded = !_expanded),
                      builder: (onTap) => TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: onTap,
                        child: Text(_expanded ? 'Less' : 'More'),
                      ),
                    ),
                ],
              );
            }),
          if (widget.cast != null) ...[
            const SizedBox(height: 10),
            Text('Starring  ${widget.cast}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: muted),
          ],
          if (widget.director != null) ...[
            const SizedBox(height: 4),
            Text('Director  ${widget.director}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
          ],
        ],
      ),
    );
  }
}
