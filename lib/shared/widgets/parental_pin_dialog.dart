import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/widgets/pin_keypad.dart';

/// Shows a 4-digit PIN entry dialog.
/// Returns the entered PIN string, or null if the user cancelled.
Future<String?> showParentalPinEntry(BuildContext context, String title) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ParentalPinDialog(title: title),
  );
}

class _ParentalPinDialog extends StatefulWidget {
  const _ParentalPinDialog({required this.title});
  final String title;

  @override
  State<_ParentalPinDialog> createState() => _ParentalPinDialogState();
}

class _ParentalPinDialogState extends State<_ParentalPinDialog> {
  String _pin = '';
  final _firstDigitFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _firstDigitFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _firstDigitFocusNode.dispose();
    super.dispose();
  }

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    final next = _pin + d;
    setState(() => _pin = next);
    if (next.length == 4) {
      // Auto-submit when 4 digits entered.
      Future.microtask(() {
        if (mounted) Navigator.of(context).pop(next);
      });
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline,
                size: 32, color: theme.colorScheme.primary),
            const SizedBox(height: 10),
            Text(widget.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            PinKeypad(
              pin: _pin,
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              firstDigitFocusNode: _firstDigitFocusNode,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prompts for an admin PIN and verifies it. Shows an "Incorrect PIN"
/// snackbar on a wrong entry. Returns true only for a valid admin PIN.
Future<bool> promptAdminPin(
    BuildContext context, WidgetRef ref, String title) async {
  final pin = await showParentalPinEntry(context, title);
  if (pin == null || !context.mounted) return false;
  if (await ref.read(profileServiceProvider).verifyAnyAdminPin(pin)) {
    return true;
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
  }
  return false;
}

/// Returns true if [category] may be opened: it is not locked, or the user
/// entered a valid admin PIN (which unlocks it for the rest of the session).
Future<bool> ensureCategoryUnlocked(
    BuildContext context, WidgetRef ref, String category) async {
  final prefs = ref.read(appPreferencesProvider).valueOrNull;
  final sessionUnlocked = ref.read(parentalSessionUnlockedProvider);
  if (prefs == null || !isCategoryLocked(category, prefs, sessionUnlocked)) {
    return true;
  }
  if (!await promptAdminPin(
      context, ref, 'Enter admin PIN to unlock "$category"')) {
    return false;
  }
  ref.read(parentalSessionUnlockedProvider.notifier).state = {
    ...ref.read(parentalSessionUnlockedProvider),
    category,
  };
  return context.mounted;
}
