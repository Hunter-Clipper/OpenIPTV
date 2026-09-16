import 'package:flutter/widgets.dart';

/// Exposes the TV nav rail's "currently active item" FocusNode to content
/// screens, so a screen can send D-pad focus back to the rail from a spot
/// Flutter's own directional search can't reach on its own — e.g. a search
/// TextField, which swallows arrow keys for its own cursor movement and so
/// never reaches the rail via ordinary directional traversal.
class TvNavRailFocus extends InheritedWidget {
  const TvNavRailFocus({
    super.key,
    required this.focusNode,
    required super.child,
  });

  final FocusNode focusNode;

  static FocusNode? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TvNavRailFocus>()?.focusNode;

  @override
  bool updateShouldNotify(TvNavRailFocus oldWidget) =>
      focusNode != oldWidget.focusNode;
}
