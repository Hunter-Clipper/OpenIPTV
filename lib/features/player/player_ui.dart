import 'package:flutter/material.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

/// Building blocks shared by the player's controls, settings sheet and
/// channel switcher — the Material 3 look of the rest of the app, adapted to
/// sit over video: round icon buttons, the user's accent for "on" states, and
/// the TV convention of a white focus fill with a dark icon.

/// Sizes scale up for TV (viewed from across the room) and down for phones.
class PlayerMetrics {
  const PlayerMetrics._(this.scale);

  factory PlayerMetrics.of(BuildContext context) {
    if (PlatformHelper.isTV(context)) return const PlayerMetrics._(1.15);
    final short = MediaQuery.sizeOf(context).shortestSide;
    return PlayerMetrics._(short < 500 ? 0.86 : 1.0);
  }

  final double scale;

  double get edge => 32 * scale;
  double get playSize => 76 * scale;
  double get skipSize => 56 * scale;
  double get actionSize => 46 * scale;
  double get transportGap => 36 * scale;
  double get titleSize => 24 * scale;
  double get bodySize => 14 * scale;
}

enum PlayerButtonStyle {
  /// Bare icon over the scrim (the action row).
  plain,

  /// Translucent disc — floats over the picture (rewind / forward, back).
  tonal,

  /// Solid accent disc — the one primary action (play / pause).
  primary,
}

/// Round, D-pad-focusable player button with a touch ripple.
class PlayerButton extends StatefulWidget {
  const PlayerButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.size,
    this.focusNode,
    this.style = PlayerButtonStyle.plain,
    this.selected = false,
    this.dimmed = false,
    this.autofocus = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final FocusNode? focusNode;
  final PlayerButtonStyle style;
  // On-state (CC on, favourited): accent-tinted disc and icon.
  final bool selected;
  // Available but nothing to act on yet (CC before captions are detected).
  final bool dimmed;
  final bool autofocus;

  @override
  State<PlayerButton> createState() => _PlayerButtonState();
}

class _PlayerButtonState extends State<PlayerButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Focus fill only on TV — on touch the play button keeps focus after
    // the controls appear and would otherwise look permanently selected.
    final lit = _focused && PlatformHelper.isTV(context);

    final Color bg;
    final Color fg;
    if (lit) {
      bg = Colors.white;
      fg = Colors.black;
    } else if (widget.style == PlayerButtonStyle.primary) {
      bg = scheme.primary;
      fg = scheme.onPrimary;
    } else if (widget.selected) {
      bg = scheme.primary.withValues(alpha: 0.22);
      fg = scheme.primary;
    } else if (widget.style == PlayerButtonStyle.tonal) {
      bg = Colors.black.withValues(alpha: 0.42);
      fg = Colors.white;
    } else {
      bg = Colors.transparent;
      fg = widget.dimmed ? Colors.white38 : Colors.white;
    }

    return TvFocusable(
      onTap: widget.onTap,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      wrapsGesture: false,
      showFocusRing: false,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Tooltip(
        message: widget.tooltip,
        child: AnimatedScale(
          scale: lit ? 1.1 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Material(
            type: MaterialType.circle,
            color: bg,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              splashColor: Colors.white24,
              highlightColor: Colors.white10,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
                child: Icon(widget.icon,
                    color: fg, size: widget.size * 0.52),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frame for the player's bottom sheets: Material 3 surface, drag handle,
/// title, capped width (it floats over landscape video) and scrolling body.
class PlayerSheet extends StatelessWidget {
  const PlayerSheet({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 4),
            child: Text(title,
                style: theme.textTheme.titleLarge!
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a [PlayerSheet]-style modal: capped width, rounded M3 corners.
Future<T?> showPlayerSheet<T>(BuildContext context, WidgetBuilder builder) {
  final theme = Theme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: theme.colorScheme.surfaceContainerHigh,
    constraints: BoxConstraints(
      maxWidth: 640,
      maxHeight: MediaQuery.sizeOf(context).height * 0.86,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: builder,
  );
}

/// A labelled row of choices in a player sheet ("Speed": 0.5x … 2x).
class OptionRow<T> extends StatelessWidget {
  const OptionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.autofocusSelected = false,
  });

  final IconData icon;
  final String label;
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool autofocusSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(label,
                    style: theme.textTheme.titleSmall!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (final (value, text) in options)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _OptionChip(
                      label: text,
                      selected: value == selected,
                      autofocus: autofocusSelected && value == selected,
                      onTap: () => onSelected(value),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.autofocus = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TvFocusable(
      onTap: onTap,
      autofocus: autofocus,
      wrapsGesture: false,
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerHighest,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check_rounded, size: 18, color: scheme.onPrimary),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
