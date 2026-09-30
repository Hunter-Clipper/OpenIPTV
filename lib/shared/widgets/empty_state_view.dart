import 'package:flutter/material.dart';

/// Standardized "there's nothing here yet" placeholder: icon in a soft
/// tinted circle, an optional title, a message and an optional call to
/// action. Used for empty lists (no favorites, no search results, no
/// profiles) so every screen communicates this the same way.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String? title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return StateMessage(
      icon: icon,
      iconColor: color,
      title: title,
      message: message,
      action: actionLabel != null && onAction != null
          ? FilledButton(
              autofocus: true,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              onPressed: onAction,
              child: Text(actionLabel!),
            )
          : null,
    );
  }
}

/// Shared layout of [EmptyStateView] and ErrorStateView.
class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.message,
    this.title,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String? title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 42, color: iconColor),
              ),
              const SizedBox(height: 20),
              if (title != null) ...[
                Text(
                  title!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 24),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
