import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// A network picture for posters, logos and backdrops.
///
/// On Android it is [CachedNetworkImage] (disk cache and all). In a browser
/// that loader has to read the picture's bytes, which most image hosts forbid
/// to other websites (CORS) — so there the picture is asked for the way a
/// plain web page would: bytes first, and an `<img>` element when the host
/// refuses. A page may show any host's image that way; it just can't read it.
class NetImage extends StatelessWidget {
  const NetImage({
    super.key,
    required this.imageUrl,
    this.cacheManager,
    this.fit,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
  });

  final String imageUrl;
  final BaseCacheManager? cacheManager;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final Duration fadeInDuration;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        cacheManager: cacheManager,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        placeholder: placeholder,
        errorWidget: errorWidget,
        fadeInDuration: fadeInDuration,
        memCacheWidth: memCacheWidth,
        memCacheHeight: memCacheHeight,
        maxWidthDiskCache: maxWidthDiskCache,
        maxHeightDiskCache: maxHeightDiskCache,
      );
    }
    return Image.network(
      imageUrl,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      cacheWidth: memCacheWidth,
      cacheHeight: memCacheHeight,
      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      loadingBuilder: placeholder == null
          ? null
          : (context, child, progress) =>
              progress == null ? child : placeholder!(context, imageUrl),
      errorBuilder: errorWidget == null
          ? null
          : (context, error, _) => errorWidget!(context, imageUrl, error),
    );
  }
}
