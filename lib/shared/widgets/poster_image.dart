import 'package:flutter/material.dart';
import 'package:open_iptv/core/services/image_cache_manager.dart';
import 'package:open_iptv/shared/widgets/net_image.dart';

/// Standardized movie/series poster thumbnail with a consistent placeholder
/// and error fallback (a filled surface + outline movie icon). Reimplemented
/// near-verbatim across Movies/Series list, grid, and detail screens before
/// being consolidated here.
class PosterImage extends StatelessWidget {
  const PosterImage({
    super.key,
    required this.posterUrl,
    this.width,
    this.height,
    this.iconSize = 24,
    this.fallbackIcon = Icons.movie_outlined,
  });

  final String? posterUrl;
  final double? width;
  final double? height;
  final double iconSize;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final fallbackColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    if (posterUrl == null || posterUrl!.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: fallbackColor,
        child: Center(
          child: Icon(fallbackIcon, size: iconSize),
        ),
      );
    }
    return NetImage(
      imageUrl: posterUrl!,
      cacheManager: ImageCacheManager(),
      fit: BoxFit.cover,
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      memCacheWidth: width?.toInt() ?? 165,
      memCacheHeight: height?.toInt() ?? 240,
      maxWidthDiskCache: 330,
      maxHeightDiskCache: 480,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: fallbackColor,
      ),
      errorWidget: (_, __, ___) => Container(
        width: width,
        height: height,
        color: fallbackColor,
        child: Center(child: Icon(fallbackIcon, size: iconSize)),
      ),
    );
  }
}
