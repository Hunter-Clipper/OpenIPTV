import 'package:flutter/material.dart';

/// Standardized group-label header shown above a section of content
/// (e.g. "Continue Watching", "Sources", "Locked Categories"). Renders as an
/// uppercase, letter-spaced label — the canonical style chosen during the
/// app-wide consistency pass, previously reimplemented per-screen with three
/// different visual treatments.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.padding});

  final String title;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Sliver-compatible wrapper for [SectionHeader], for use directly inside a
/// CustomScrollView's slivers list.
class SectionHeaderSliver extends StatelessWidget {
  const SectionHeaderSliver(this.title, {super.key, this.padding});

  final String title;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) =>
      SectionHeader(title, padding: padding);
}
