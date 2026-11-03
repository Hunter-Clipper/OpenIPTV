import 'dart:ui';

import 'package:flutter/animation.dart';

/// True when the system asks for no animations (Android's "Remove
/// animations", Settings → Accessibility). Safe to read in `initState`.
bool get reduceMotion =>
    PlatformDispatcher.instance.accessibilityFeatures.disableAnimations;

/// Starts an endless decorative loop, unless motion is reduced — then the
/// controller stays at its first frame, so the widget shows a still state.
void loopUnlessReduced(AnimationController c, {bool reverse = false}) {
  if (reduceMotion) return;
  c.repeat(reverse: reverse);
}
