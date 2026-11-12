import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_iptv/shared/utils/motion.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

/// Shared state so only one tooltip is open across the entire screen.
class InfoTooltipController extends ChangeNotifier {
  String? _openId;

  bool isOpen(String id) => _openId == id;

  void toggle(String id) {
    _openId = _openId == id ? null : id;
    notifyListeners();
  }

  void closeAll() {
    _openId = null;
    notifyListeners();
  }
}

class InfoTooltipScope extends InheritedNotifier<InfoTooltipController> {
  const InfoTooltipScope({
    super.key,
    required InfoTooltipController controller,
    required super.child,
  }) : super(notifier: controller);

  static InfoTooltipController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InfoTooltipScope>()?.notifier;

  static InfoTooltipController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<InfoTooltipScope>();
    assert(scope != null, 'InfoTooltipScope not found in widget tree');
    return scope!.notifier!;
  }
}

/// Width an (ℹ) button takes at the end of a row.
const double kInfoGutter = 54;

class _InfoRowMarker extends InheritedWidget {
  const _InfoRowMarker({required super.child});

  @override
  bool updateShouldNotify(_InfoRowMarker old) => false;
}

/// Wrap a settings row that has no (ℹ) so its chevron / switch lines up with
/// the rows that do. Does nothing outside a settings page (no scope) or
/// inside an [InfoTooltip] row.
class InfoGutter extends StatelessWidget {
  const InfoGutter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (InfoTooltipScope.maybeOf(context) == null ||
        context.getInheritedWidgetOfExactType<_InfoRowMarker>() != null) {
      return child;
    }
    return Padding(
        padding: const EdgeInsets.only(right: kInfoGutter), child: child);
  }
}

/// Wraps a row with an (ℹ) icon that expands an explanatory card inline.
///
/// Usage:
/// ```dart
/// InfoTooltip(
///   id: 'epg_url',
///   title: 'EPG Source URL',
///   body: 'A link to a TV guide...',
///   child: Text('EPG Source URL'),
/// )
/// ```
class InfoTooltip extends StatelessWidget {
  const InfoTooltip({
    super.key,
    required this.id,
    required this.title,
    required this.body,
    required this.child,
    this.tip,
  });

  final String id;
  final String title;
  final String body;
  final String? tip;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: InfoTooltipScope.of(context),
      builder: (context, _) {
        final controller = InfoTooltipScope.of(context);
        final isOpen = controller.isOpen(id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _InfoRowMarker(child: child)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  // Up / Down from the (ℹ) go to the neighbouring ROWS, not
                  // along a column of tiny buttons; Left comes back to the row.
                  child: Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    onKeyEvent: (node, event) {
                      if (event is KeyUpEvent) return KeyEventResult.ignored;
                      final up = event.logicalKey == LogicalKeyboardKey.arrowUp;
                      final down =
                          event.logicalKey == LogicalKeyboardKey.arrowDown;
                      if (!up && !down) return KeyEventResult.ignored;
                      if (event is KeyDownEvent || event is KeyRepeatEvent) {
                        final fm = FocusManager.instance;
                        fm.primaryFocus
                            ?.focusInDirection(TraversalDirection.left);
                        fm.primaryFocus?.focusInDirection(up
                            ? TraversalDirection.up
                            : TraversalDirection.down);
                      }
                      return KeyEventResult.handled;
                    },
                    child: TvFocusable(
                      onTap: () => controller.toggle(id),
                      borderRadius: BorderRadius.circular(24),
                      focusScale: 1.15,
                      // A roomy round target, so the focus pill is easy to see.
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.info_outline,
                          size: 18,
                          color: isOpen
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: motionDuration(const Duration(milliseconds: 200)),
              curve: Curves.easeInOut,
              child: isOpen
                  ? _TooltipCard(title: title, body: body, tip: tip)
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({
    required this.title,
    required this.body,
    this.tip,
  });

  final String title;
  final String body;
  final String? tip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium!
                .copyWith(color: scheme.primary),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (tip != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline,
                    size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tip!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
