import 'package:flutter/material.dart';

/// OpenIPTV logo for use in AppBar leading slots.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Image.asset('assets/images/logo.jpg', fit: BoxFit.contain),
    );
  }
}
