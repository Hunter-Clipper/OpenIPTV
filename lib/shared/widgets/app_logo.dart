import 'package:flutter/material.dart';

/// OpenIPTV logo for use in AppBar leading slots.
/// Automatically selects the light or dark variant to match the current theme.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Image.asset(
        isDark
            ? 'assets/images/app_icon_dark.png'
            : 'assets/images/app_icon_light.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
