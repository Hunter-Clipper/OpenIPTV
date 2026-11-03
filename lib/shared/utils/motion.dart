import 'package:flutter/animation.dart';
import 'package:flutter/widgets.dart';

/// True when the system asks for no animations (Android's "Remove
/// animations", Settings → Accessibility). Safe to read in `initState`.
bool get reduceMotion => WidgetsBinding
    .instance.platformDispatcher.accessibilityFeatures.disableAnimations;

/// Starts an endless decorative loop, unless motion is reduced — then the
/// controller stays at its first frame, so the widget shows a still state.
void loopUnlessReduced(AnimationController c, {bool reverse = false}) {
  if (reduceMotion) return;
  c.repeat(reverse: reverse);
}

/// A duration that collapses to zero when motion is reduced, so a slide,
/// scale or scroll becomes an instant change. Wrap the `duration:` of any
/// implicit animation or programmatic scroll.
Duration motionDuration(Duration d) => reduceMotion ? Duration.zero : d;
