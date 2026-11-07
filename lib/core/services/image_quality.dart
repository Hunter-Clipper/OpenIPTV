import 'package:flutter/widgets.dart';

/// Settings → Power User Tools → Full-resolution pictures.
///
/// With full resolution on (the default), posters, logos and backdrops
/// decode at up to [fullMaxWidth] pixels wide. Off, they decode at roughly
/// the size they are drawn (light on memory). The original file is cached
/// either way, so switching needs no re-download.
class ImageQuality extends InheritedWidget {
  const ImageQuality({super.key, required this.full, required super.child});

  /// Full-resolution pictures are on.
  final bool full;

  /// The widest a picture is decoded in full-resolution mode (backdrops get
  /// [fullMaxBackdropWidth]). Bigger than this is rarely visible and costs
  /// a lot of memory: a 2000x3000 poster is ~24 MB once decoded.
  static const fullMaxWidth = 1280;
  static const fullMaxBackdropWidth = 2560;

  /// Flutter's in-memory picture budget. The default is too small for
  /// full-resolution pictures (they would be thrown out and decoded again
  /// as you scroll).
  static const standardCacheBytes = 100 << 20;
  static const fullCacheBytes = 256 << 20;

  static bool isFull(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ImageQuality>()?.full ??
      false;

  /// Applies the memory budget for [full] (call when the setting changes
  /// and at start-up).
  static void applyCacheBudget(bool full) {
    PaintingBinding.instance.imageCache.maximumSizeBytes =
        full ? fullCacheBytes : standardCacheBytes;
  }

  @override
  bool updateShouldNotify(ImageQuality old) => full != old.full;
}

extension ImageQualityContext on BuildContext {
  /// The width to decode a picture at: [standard] normally, up to
  /// [ImageQuality.fullMaxWidth] (or [fullMax]) in full-resolution mode.
  int imageDecodeWidth(int standard, {int? fullMax}) {
    if (!ImageQuality.isFull(this)) return standard;
    final cap = fullMax ?? ImageQuality.fullMaxWidth;
    return standard > cap ? standard : cap;
  }

  /// The height to decode at: [standard] normally; in full-resolution mode
  /// null, so the picture keeps its own shape at the width above.
  int? imageDecodeHeight(int? standard) =>
      ImageQuality.isFull(this) ? null : standard;
}
