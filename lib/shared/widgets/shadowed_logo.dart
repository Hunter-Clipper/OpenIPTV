import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:open_iptv/core/services/image_cache_manager.dart';

/// A channel logo with a soft, feathered glow all round (the Retro Cable look,
/// #178). The logo and its blurred shadow are drawn together once into a
/// bitmap that is kept, so the guide only draws a flat image per frame: a
/// blur filter drawn live is not cached by the renderer and halved the
/// guide's frame rate on the TV.
class ShadowedLogo extends StatefulWidget {
  const ShadowedLogo({
    super.key,
    required this.url,
    required this.size,
    required this.shadow,
    required this.decodeWidth,
    required this.fallback,
  });

  final String url;

  /// The room for the logo and its shadow, in logical pixels.
  final Size size;
  final Color shadow;
  final int decodeWidth;

  /// Shown if the logo can't be loaded.
  final Widget fallback;

  @override
  State<ShadowedLogo> createState() => _ShadowedLogoState();
}

class _ShadowedLogoState extends State<ShadowedLogo> {
  // Composed bitmaps, by logo, size and colour. Kept for the run of the app.
  static final Map<String, ui.Image> _cache = {};

  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;
  bool _failed = false;
  double _dpr = 1;

  String get _key =>
      '${widget.url}|${widget.size.width.round()}x${widget.size.height.round()}'
      '|$_dpr|${widget.shadow.toARGB32()}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    if (dpr != _dpr || _stream == null) {
      _dpr = dpr;
      _load();
    }
  }

  @override
  void didUpdateWidget(ShadowedLogo old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url ||
        old.size != widget.size ||
        old.shadow != widget.shadow) {
      _load();
    }
  }

  void _load() {
    final cached = _cache[_key];
    if (cached != null) {
      _image = cached;
      _failed = false;
      return;
    }
    _image = null;
    _failed = false;
    _detach();
    final provider = CachedNetworkImageProvider(
      widget.url,
      cacheManager: ImageCacheManager(),
      maxWidth: widget.decodeWidth,
    );
    final key = _key;
    final stream = provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((info, _) async {
      final composed = await _compose(info.image);
      if (!mounted || key != _key) return;
      if (_cache.length > 300) _cache.clear();
      _cache[key] = composed;
      setState(() => _image = composed);
    }, onError: (_, __) {
      if (mounted) setState(() => _failed = true);
    });
    _stream = stream..addListener(_listener!);
  }

  void _detach() {
    final l = _listener;
    if (l != null) _stream?.removeListener(l);
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  Future<ui.Image> _compose(ui.Image logo) {
    final w = (widget.size.width * _dpr).round();
    final h = (widget.size.height * _dpr).round();
    // A glow on every side (not a drop shadow to one corner): room is left
    // all round for it to spread into.
    final sigma = h * 0.09;
    final margin = sigma * 1.1;
    final room = Size(w - margin * 2, h - margin * 2);
    final src = Size(logo.width.toDouble(), logo.height.toDouble());
    final fitted = applyBoxFit(BoxFit.contain, src, room);
    final dst = Alignment.center.inscribe(fitted.destination,
        Rect.fromLTWH(margin, margin, room.width, room.height));
    final srcRect = Offset.zero & src;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final glow = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = ColorFilter.mode(widget.shadow, BlendMode.srcIn)
      ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    // Three passes: one pass of a blur is thin once it has spread out.
    for (var i = 0; i < 3; i++) {
      canvas.drawImageRect(logo, srcRect, dst, glow);
    }
    canvas.drawImageRect(
        logo, srcRect, dst, Paint()..filterQuality = FilterQuality.medium);
    return recorder.endRecording().toImage(w, h);
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return widget.fallback;
    final image = _image;
    if (image == null) {
      // Until the shadowed version is ready, the plain logo.
      return CachedNetworkImage(
        imageUrl: widget.url,
        cacheManager: ImageCacheManager(),
        fit: BoxFit.contain,
        memCacheWidth: widget.decodeWidth,
        errorWidget: (_, __, ___) => widget.fallback,
      );
    }
    return RawImage(image: image, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
  }
}
