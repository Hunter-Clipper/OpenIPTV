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
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool autofocus;
  final BorderRadius? borderRadius;
  // Extra hook for callers that need to react to focus changes themselves
  // (e.g. the TV guide grid syncing its shared scroll position) — runs
  // alongside, not instead of, this widget's own focus-ring/scroll handling.
  // Wrapping a TvFocusable in a second Focus widget for this instead would
  // create a second, competing FocusNode in the traversal order.
  final ValueChanged<bool>? onFocusChange;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;

  void _handleFocusChange(bool focused) {
    setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
    if (focused) {
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
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            border: Border.all(
              color: _focused ? accent : Colors.transparent,
              width: 3,
            ),
            borderRadius: radius,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
