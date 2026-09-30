import 'package:flutter/material.dart';
import 'package:open_iptv/shared/widgets/empty_state_view.dart';

/// Standardized load-failure placeholder: icon + message + retry button.
/// One icon for every failure class (list load, connectivity, detail
/// lookup) — the app previously mixed it with a wifi-specific icon with no
/// clear rule for which failures got which glyph.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.retryIcon = Icons.refresh_rounded,
  });

  final String? title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData retryIcon;

  @override
  Widget build(BuildContext context) {
    return StateMessage(
      icon: Icons.cloud_off_rounded,
      iconColor: Theme.of(context).colorScheme.error,
      title: title,
      message: message,
      action: onRetry == null
          ? null
          : FilledButton.icon(
              autofocus: true,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              icon: Icon(retryIcon),
              label: Text(retryLabel),
              onPressed: onRetry,
            ),
    );
  }
}
