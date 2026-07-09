import 'package:flutter/material.dart';

/// Standardized 4-digit PIN entry: dot progress indicator + numeric keypad.
/// Used by both the parental-PIN dialog and the setup wizard's PIN step,
/// which previously implemented this twice with different button widgets
/// and dimensions.
class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.pin,
    required this.onDigit,
    required this.onBackspace,
    this.length = 4,
  });

  final String pin;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final int length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(length, (i) {
            final filled = i < pin.length;
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
        ...rows.map((row) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 72, height: 52);
                }
                return SizedBox(
                  width: 72,
                  height: 52,
                  child: TextButton(
                    onPressed: key == '⌫' ? onBackspace : () => onDigit(key),
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
      ],
    );
  }
}
