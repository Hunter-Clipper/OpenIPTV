import 'package:flutter/material.dart';

/// Shows a snack bar, hiding any current one first.
void showSnackBarMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
