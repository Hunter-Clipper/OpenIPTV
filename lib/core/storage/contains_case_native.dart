import 'package:drift/drift.dart';
import 'package:drift/extensions/native.dart';

/// Case-insensitive "contains" using Dart's own case folding (drift's native
/// `containsCase`, a Dart callback run per row).
Expression<bool> containsCaseFolded(Expression<String> text, String query) =>
    text.containsCase(query);
