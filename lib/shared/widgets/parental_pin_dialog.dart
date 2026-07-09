import 'package:flutter/material.dart';
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
