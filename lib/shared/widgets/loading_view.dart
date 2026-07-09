import 'package:flutter/material.dart';

/// Standardized centered loading spinner used while a screen's initial data
/// is being fetched.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
