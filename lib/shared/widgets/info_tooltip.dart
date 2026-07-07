import 'package:flutter/material.dart';

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

  static InfoTooltipController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<InfoTooltipScope>();
    assert(scope != null, 'InfoTooltipScope not found in widget tree');
    return scope!.notifier!;
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
                Expanded(child: child),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => controller.toggle(id),
                    child: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: isOpen
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
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
