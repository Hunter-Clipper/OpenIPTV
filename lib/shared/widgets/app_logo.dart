import 'package:flutter/material.dart';

/// OpenIPTV logo for use in AppBar leading slots.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(8),
      child: Image(
        image: AssetImage('assets/images/app_icon_dark.png'),
        fit: BoxFit.contain,
      ),
    );
  }
}
