import 'package:flutter/material.dart';

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
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

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
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            // Number pad
            ...rows.map((row) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: row.map((key) {
                    if (key.isEmpty) return const SizedBox(width: 72, height: 52);
                    return SizedBox(
                      width: 72,
                      height: 52,
                      child: TextButton(
                        onPressed:
                            key == '⌫' ? _onBackspace : () => _onDigit(key),
                        child: Text(
                          key,
                          style: key == '⌫'
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.headlineSmall,
                        ),
                      ),
                    );
                  }).toList(),
                )),
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
