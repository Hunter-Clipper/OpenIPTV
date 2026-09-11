import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';

/// Wraps [child] so it can receive D-pad/keyboard focus: shows an animated
/// accent focus ring (matching AppTheme.focusDecoration) when focused,
/// activates [onTap] on remote OK/Enter, and scrolls itself into view when
/// focused inside a scrollable list/grid. This is additive to (not a
/// replacement for) normal tap handling, and is unconditional — harmless on
/// phone/tablet, essential on TV where nothing else shows where the D-pad
/// cursor is.
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

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;

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
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final radius = widget.borderRadius ??
        BorderRadius.circular(AppTheme.cardRadius);
    final ring = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        border: Border.all(
          color: _focused ? accent : Colors.transparent,
          width: 3,
        ),
        borderRadius: radius,
      ),
      child: widget.child,
    );
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: widget.wrapsGesture
          ? GestureDetector(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              child: ring,
            )
          : ring,
    );
  }
}
