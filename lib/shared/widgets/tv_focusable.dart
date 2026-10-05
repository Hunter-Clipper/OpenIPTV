import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/widgets/tv_nav_rail_focus.dart';
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
    if (event is KeyRepeatEvent) {
      // Android only starts repeating a held key after its own long-press
      // timeout, so the first repeat *is* the platform's long-press — don't
      // wait out the rest of our timer.
      if (_keyDownActive && !_longPressFired) {
        _longPressTimer?.cancel();
        _longPressFired = true;
        widget.onLongPress!();
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
      // Painted as a foreground ring so it takes no layout space: as a
      // regular (transparent-until-focused) border it inset every focusable
      // widget by 3px, misaligning it against non-focusable siblings (e.g.
      // the active, non-tappable row in a list of tappable ones).
      content = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        foregroundDecoration: BoxDecoration(
          border: Border.all(
            // White, not the accent: the accent already marks *selected*
            // things (chosen avatar, active playlist), and a focus ring in
            // the same colour made the two indistinguishable on TV.
            color: lit ? Colors.white : Colors.transparent,
            width: 3,
          ),
          borderRadius: widget.borderRadius ??
              BorderRadius.circular(AppTheme.cardRadius),
        ),
        child: PlatformHelper.isTV(context)
            // The ring is the focus indicator on TV. A wrapped ListTile or
            // button would also paint its own ink focus fill — a second,
            // differently-sized highlight under the ring.
            ? Theme(
                data: Theme.of(context)
                    .copyWith(focusColor: Colors.transparent),
                child: widget.child,
              )
            : widget.child,
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

/// App-wide D-pad escape from text fields on TV. A single-line TextField
/// maps Up/Down to caret moves that go nowhere, swallowing them before the
/// directional focus system sees them — so a remote could get *into* a
/// field but never back out (the setup wizard's last field trapped focus
/// above its "Load My Playlist" button). Sitting above every route, this
/// sees the key first (bubbling from the focused field, before the app's
/// text-editing shortcuts) and moves focus up/down instead.
class TvTextFieldEscape extends StatelessWidget {
  const TvTextFieldEscape({super.key, required this.child});

  final Widget child;

  static KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || !PlatformHelper.isTVDevice) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final down = key == LogicalKeyboardKey.arrowDown;
    if (!down && key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    final focused = FocusManager.instance.primaryFocus;
    final editable =
        focused?.context?.findAncestorWidgetOfExactType<EditableText>();
    if (focused == null || editable == null || editable.maxLines != 1) {
      return KeyEventResult.ignored;
    }
    final moved = focused.focusInDirection(
            down ? TraversalDirection.down : TraversalDirection.up) ||
        (down ? focused.nextFocus() : focused.previousFocus());
    return moved ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: child,
      );
}

/// Popup menu items have no focus ring of their own — only an ink fill,
/// which at the default strength is invisible from across the room. Wrap a
/// PopupMenuButton in this (the menu inherits the button's theme).
class TvMenuTheme extends StatelessWidget {
  const TvMenuTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context)
            .copyWith(focusColor: Colors.white.withValues(alpha: 0.24)),
        child: child,
      );
}

/// On TV, focuses the nearest enclosing focusable (the ink of a
/// [PopupMenuItem], say) when first shown. Popup menus open with nothing
/// focused, so the remote's OK and arrows had no visible target; wrap the
/// first item's child in this.
class TvInitialFocus extends StatefulWidget {
  const TvInitialFocus({super.key, required this.child});

  final Widget child;

  @override
  State<TvInitialFocus> createState() => _TvInitialFocusState();
}

class _TvInitialFocusState extends State<TvInitialFocus> {
  @override
  void initState() {
    super.initState();
    if (!PlatformHelper.isTVDevice) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Focus.maybeOf(context)?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Keeps Left/Right inside one horizontal row on TV. Flutter's directional
/// search considers every focusable on screen, so at the start of a row
/// whose neighbour row was scrolled, Left jumped to a half-hidden poster in
/// the other row instead of the side menu. Here Left/Right move to the
/// nearest item of this row; Left past the first goes to the nav rail,
/// Right past the last stays put. Up/Down are handed on unchanged.
class TvRowFocus extends StatefulWidget {
  const TvRowFocus({super.key, required this.child});

  final Widget child;

  @override
  State<TvRowFocus> createState() => _TvRowFocusState();
}

class _TvRowFocusState extends State<TvRowFocus> {
  final _row = FocusNode(canRequestFocus: false, skipTraversal: true);

  @override
  void dispose() {
    _row.dispose();
    super.dispose();
  }

  Object? _move(DirectionalFocusIntent intent) {
    final dir = intent.direction;
    if (dir == TraversalDirection.up || dir == TraversalDirection.down) {
      // This State's context sits above the Actions built below, so this
      // reaches whatever handled the press before (shell, app default).
      return Actions.maybeInvoke(context, intent);
    }
    final current = FocusManager.instance.primaryFocus;
    if (current == null) return null;
    final from = current.rect.center.dx;
    final sign = dir == TraversalDirection.right ? 1 : -1;
    FocusNode? best;
    var bestDistance = double.infinity;
    for (final node in _row.traversalDescendants) {
      if (identical(node, current) || node.context == null) continue;
      // A card's own nested focusables share its centre — skip those.
      final distance = (node.rect.center.dx - from) * sign;
      if (distance > 1 && distance < bestDistance) {
        best = node;
        bestDistance = distance;
      }
    }
    if (best != null) {
      best.requestFocus();
      Scrollable.ensureVisible(
        best.context!,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        alignmentPolicy: sign > 0
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    } else if (dir == TraversalDirection.left) {
      TvNavRailFocus.maybeOf(context)?.requestFocus();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformHelper.isTV(context)) return widget.child;
    return Actions(
      actions: {
        DirectionalFocusIntent:
            CallbackAction<DirectionalFocusIntent>(onInvoke: _move),
      },
      child: Focus(focusNode: _row, child: widget.child),
    );
  }
}

/// A text field the TV remote can move past without the on-screen keyboard
/// popping up (#29). On TV the field's outline is the focus stop; OK opens
/// the keyboard (focuses the real [TextField]), and finishing ("Next" /
/// "Done") or Up/Down hands the remote back to the outlines. Focusing a
/// field directly — how Flutter normally works — opens Google TV's
/// full-screen keyboard at once, hiding which field it was for. The
/// selected field is also scrolled into view.
///
/// [builder] receives the node to give the TextField. [focusNode], when
/// given, is the outline's node, so a screen can still move the remote
/// to a particular field. On phones and tablets this is the plain field.
class TvTextFieldGate extends StatefulWidget {
  const TvTextFieldGate({
    super.key,
    required this.builder,
    this.focusNode,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final Widget Function(BuildContext context, FocusNode fieldNode) builder;
  final FocusNode? focusNode;
  final BorderRadius borderRadius;

  @override
  State<TvTextFieldGate> createState() => _TvTextFieldGateState();
}

class _TvTextFieldGateState extends State<TvTextFieldGate> {
  FocusNode? _ownGate;
  FocusNode get _gate => widget.focusNode ?? (_ownGate ??= FocusNode());
  // Not a D-pad stop itself: traversal moves between gates, and leaving a
  // field with Next/Up/Down lands on the neighbouring gate, not its field.
  final _field = FocusNode(skipTraversal: true);
  bool _gateFocused = false;

  @override
  void initState() {
    super.initState();
    _field.addListener(_onFieldFocus);
  }

  @override
  void dispose() {
    _field.removeListener(_onFieldFocus);
    _field.dispose();
    _ownGate?.dispose();
    super.dispose();
  }

  void _onFieldFocus() {
    if (mounted) setState(() {});
  }

  // Scrolls only the nearest *vertical* scrollable. Scrollable.ensureVisible
  // would also move every scrollable above it — in the setup wizard that's
  // the sideways page view, which jolted the page left on each move.
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject();
      var scrollable = Scrollable.maybeOf(context);
      while (scrollable != null &&
          scrollable.axisDirection != AxisDirection.down &&
          scrollable.axisDirection != AxisDirection.up) {
        scrollable = Scrollable.maybeOf(scrollable.context);
      }
      if (box == null || scrollable == null) return;
      scrollable.position.ensureVisible(
        box,
        alignment: 0.3,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  KeyEventResult _onGateKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      _field.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!PlatformHelper.isTV(context)) {
      return widget.builder(context, widget.focusNode ?? _field);
    }
    final lit = _gateFocused && !_field.hasFocus;
    return Focus(
      focusNode: _gate,
      onKeyEvent: _onGateKey,
      onFocusChange: (f) {
        setState(() => _gateFocused = f);
        if (f) _reveal();
      },
      child: Container(
        foregroundDecoration: BoxDecoration(
          border: Border.all(
              color: lit ? Colors.white : Colors.transparent, width: 3),
          borderRadius: widget.borderRadius,
        ),
        child: widget.builder(context, _field),
      ),
    );
  }
}
