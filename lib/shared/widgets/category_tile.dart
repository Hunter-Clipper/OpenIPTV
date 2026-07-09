import 'package:flutter/material.dart';

/// Standardized category/genre row: icon, label, item count, optional lock
/// badge, and a trailing chevron. Used for Live TV categories and Movies/
/// Series genre lists, which previously reimplemented this identically in
/// three separate files.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.onTap,
    this.isLocked = false,
    this.onLongPress,
  });

  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLocked;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLocked)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.lock_outline,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
            ),
          Text(
            count.toString(),
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
      enableFeedback: false,
      onLongPress: onLongPress,
    );
  }
}
