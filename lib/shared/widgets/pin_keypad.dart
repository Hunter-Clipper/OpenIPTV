import 'package:flutter/material.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

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
    this.firstDigitFocusNode,
  });

  final String pin;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final int length;
  // See TvFocusable.focusNode's doc — a plain `autofocus: true` on the "1"
  // button isn't reliable when this keypad appears inside a page that isn't
  // built fresh at the moment it's shown (e.g. a wizard's PageView keeps
  // every page built up front). Callers that need the keypad to have real
  // D-pad focus the instant it becomes visible should own this node and
  // call requestFocus() on it at the actual moment of navigation.
  final FocusNode? firstDigitFocusNode;

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
                  child: TvFocusable(
                    borderRadius: BorderRadius.circular(8),
                    ensureVisibleOnFocus: true,
                    focusNode: key == '1' ? firstDigitFocusNode : null,
                    onTap: key == '⌫' ? onBackspace : () => onDigit(key),
                    child: Center(
                      child: Text(
                        key,
                        style: key == '⌫'
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.headlineSmall,
                      ),
                    ),
                  ),
                );
              }).toList(),
            )),
      ],
    );
  }
}
