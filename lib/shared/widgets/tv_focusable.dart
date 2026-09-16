import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/ui/platform_helper.dart';

/// Wraps [child] so it can receive D-pad/keyboard focus: shows an animated
/// accent focus ring (matching AppTheme.focusDecoration) when focused,
/// activates [onTap] on remote OK/Enter, and scrolls itself into view when
/// focused inside a scrollable list/grid. Focus/key handling is unconditional
/// (harmless on phone/tablet — a Bluetooth keyboard or switch-access user
/// still benefits), but the visible ring itself is TV-only: a phone/tablet
/// has no D-pad cursor to show, and touch users would otherwise see a stray
/// blue outline flash on whatever they last tapped.
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.autofocus = false,
    this.borderRadius,
    this.onFocusChange,
    this.ensureVisibleOnFocus = false,
    this.wrapsGesture = true,
    this.focusNode,
    this.showFocusRing = true,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;
  final BorderRadius? borderRadius;
  // Supply this when a caller needs to explicitly request focus later (e.g.
  // a wizard page requesting focus on its first control at the moment the
  // user actually navigates to it). Without an externally-owned node here,
  // `autofocus` is the only lever — and `autofocus` only ever fires once, at
  // this exact widget's own first build, which for pages that are all built
  // up front (like a PageView's non-lazy children) can happen long before
  // the page is ever actually shown, and lose the initial focus race to
  // whatever built (and autofocused) first.
  final FocusNode? focusNode;
  // False for callers that already have their own GestureDetector for
  // pointer taps (e.g. one also driving a press-down/press-up animation) —
  // nesting a second GestureDetector claiming the same tap gesture risks
  // double-invoking onTap or fighting the gesture arena. When false, this
  // widget contributes only the focus node/ring/key-activation/scroll-into-
  // view; the caller's own GestureDetector remains the sole pointer handler.
  final bool wrapsGesture;
  // Extra hook for callers that need to react to focus changes themselves
  // (e.g. the TV guide grid syncing its shared scroll position) — runs
  // alongside, not instead of, this widget's own focus-ring/scroll handling.
  // Wrapping a TvFocusable in a second Focus widget for this instead would
  // create a second, competing FocusNode in the traversal order.
  final ValueChanged<bool>? onFocusChange;
  // Opt-in, not a default: Scrollable.ensureVisible walks up to the NEAREST
  // Scrollable ancestor, whatever that is — if a TvFocusable sits directly
  // on a page (not inside a real scrolling list), that nearest ancestor is
  // often a PageView, and ensureVisible would nudge/animate the whole page
  // horizontally on every single focus change (reported as the screen
  // "bouncing left and back" while navigating the onboarding wizard with a
  // TV remote). Only set this true for items that actually live inside a
  // scrollable list/grid that benefits from auto-scrolling the focused item
  // into view.
  final bool ensureVisibleOnFocus;
  // False for callers that paint their own bespoke focus treatment (e.g. the
  // TV nav rail's glowing pill) off the `onFocusChange` callback instead of
  // this widget's generic accent-border box. Focus/key handling and
  // scroll-into-view behavior are unaffected — only the built-in ring is
  // skipped.
  final bool showFocusRing;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;
  // Lets a held-down select/OK on the remote reach [onLongPress] the same way
  // a touch long-press does — e.g. the favorite-toggle overlay on a poster
  // card sits fully inside the card's own focus rectangle, so D-pad
  // directional navigation can never land on it as a separate stop; holding
  // select on the card itself is the only way a remote user can reach it.
  Timer? _longPressTimer;
  bool _longPressFired = false;
  // Guards against an orphaned KeyUpEvent: a select press that triggers a
  // synchronous navigation (e.g. the nav rail's context.go) can autofocus a
  // brand-new widget instance — with its own fresh _TvFocusableState — before
  // the remote's key-up for that SAME physical press is delivered. That
  // key-up then lands on the new widget, which never saw the matching
  // key-down, so _longPressFired is still false and it would otherwise look
  // exactly like a valid completed short-press and fire onTap a second time
  // on whatever the user just landed on. Only treat a key-up as real if this
  // widget instance actually recorded the key-down that started it.
  bool _keyDownActive = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _handleFocusChange(bool focused) {
    setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
    if (focused && widget.ensureVisibleOnFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final isActivationKey = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA;
    if (!isActivationKey) return KeyEventResult.ignored;

    // No long-press handler: behave exactly as before this hold-to-long-press
    // support was added — fire once on key-down and ignore the matching
    // key-up entirely. (Handling both would double-fire onTap on every plain
    // select press, which silently cancels itself out for a toggle callback.)
    if (widget.onLongPress == null) {
      if (event is KeyDownEvent) widget.onTap();
      return KeyEventResult.handled;
    }

    if (event is KeyUpEvent) {
      // Orphaned key-up (this instance never saw the key-down) — see
      // _keyDownActive's doc comment. Swallow it without firing onTap.
      if (!_keyDownActive) return KeyEventResult.handled;
      _keyDownActive = false;
      final firedLongPress = _longPressFired;
      _longPressTimer?.cancel();
      _longPressTimer = null;
      if (!firedLongPress) widget.onTap();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent) {
      _keyDownActive = true;
      // Ignore auto-repeat KeyDownEvents while a hold is already in
      // progress — only the first press of a hold should start the timer.
      if (_longPressTimer == null) {
        _longPressFired = false;
        _longPressTimer = Timer(const Duration(milliseconds: 500), () {
          _longPressFired = true;
          widget.onLongPress!();
        });
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    var content = widget.child;
    if (widget.showFocusRing) {
      final lit = _focused && PlatformHelper.isTV(context);
      content = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          border: Border.all(
            color: lit
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
          borderRadius: widget.borderRadius ??
              BorderRadius.circular(AppTheme.cardRadius),
        ),
        child: widget.child,
      );
    }
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: widget.wrapsGesture
          ? GestureDetector(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              child: content,
            )
          : content,
    );
  }
}

/// Pairs a widget that already handles its own pointer taps (a button, a
/// [ListTile], a [SwitchListTile], …) with [TvFocusable]'s D-pad/remote
/// activation, without writing the action out twice: [builder] is handed the
/// very same [onTap] the remote fires.
///
/// A null [onTap] means disabled — [builder] receives null (so the underlying
/// control renders and behaves as disabled) and no focus node is added at
/// all, keeping it out of the D-pad traversal order the way a disabled
/// Material control already is.
/// Overrides the default D-pad directional-focus action so a press in one of
/// [directions] that finds nothing to move to (Flutter's own traversal,
/// tried first via [FocusNode.focusInDirection]) falls back to [onNoMove]
/// instead of silently doing nothing. Every other direction, and every press
/// that has a real neighbor to move to, behaves exactly like Flutter's
/// built-in traversal already does.
///
/// Flutter's traversal weighs how much a candidate overlaps the current
/// node on the perpendicular axis, not just same-row/column adjacency — a
/// screen-edge button far off to one side can lose out to something closer
/// but only loosely aligned. That leaves real gaps: the player's centered
/// play/pause button has no good candidate directly above it even though
/// the screen-edge Back button is the obvious target moving up, the CC
/// button has the same gap moving left past the (non-focusable) title text
/// to that same Back button, and a content grid can have the equivalent gap
/// moving left into a side nav rail.
class EdgeAwareDirectionalFocusAction extends Action<DirectionalFocusIntent> {
  EdgeAwareDirectionalFocusAction({
    required this.directions,
    required this.onNoMove,
  });

  final Set<TraversalDirection> directions;
  final VoidCallback onNoMove;

  @override
  Object? invoke(DirectionalFocusIntent intent) {
    final moved = primaryFocus?.focusInDirection(intent.direction) ?? false;
    if (!moved && directions.contains(intent.direction)) {
      onNoMove();
    }
    return moved;
  }
}

class TvActivatable extends StatelessWidget {
  const TvActivatable({
    super.key,
    required this.onTap,
    required this.builder,
    this.autofocus = false,
    this.borderRadius,
    this.focusNode,
  });

  final VoidCallback? onTap;
  final Widget Function(VoidCallback? onTap) builder;
  final bool autofocus;
  final BorderRadius? borderRadius;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final tap = onTap;
    final child = builder(tap);
    if (tap == null) return child;
    return TvFocusable(
      wrapsGesture: false,
      onTap: tap,
      autofocus: autofocus,
      borderRadius: borderRadius,
      focusNode: focusNode,
      child: child,
    );
  }
}
