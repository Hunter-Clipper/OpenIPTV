import 'package:flutter/material.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/widgets/empty_state_view.dart';

/// Standardized load-failure placeholder: icon + message + retry button.
/// One icon for every failure class (list load, connectivity, detail
/// lookup) — the app previously mixed it with a wifi-specific icon with no
/// clear rule for which failures got which glyph.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.retryLabel,
    this.retryIcon = Icons.refresh_rounded,
  });

  /// Defaults to the localized "Couldn't load this".
  final String? title;
  final String message;
  final VoidCallback? onRetry;

  /// Defaults to the localized "Try Again".
  final String? retryLabel;
  final IconData retryIcon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StateMessage(
      icon: Icons.cloud_off_rounded,
      iconColor: Theme.of(context).colorScheme.error,
      title: title ?? l10n.errorStateTitle,
      message: message,
      action: onRetry == null
          ? null
          : FilledButton.icon(
              autofocus: true,
              style: FilledButton.styleFrom(shape: const StadiumBorder()),
              icon: Icon(retryIcon),
              label: Text(retryLabel ?? l10n.errorStateTryAgain),
              onPressed: onRetry,
            ),
    );
  }
}
