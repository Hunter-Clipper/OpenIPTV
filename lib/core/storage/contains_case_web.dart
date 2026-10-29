import 'package:drift/drift.dart';

/// Web has no Dart callbacks inside SQLite, so non-ASCII text falls back to
/// SQLite's LIKE, which only folds ASCII case (é and É differ).
Expression<bool> containsCaseFolded(Expression<String> text, String query) {
  final escaped =
      query.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}');
  return text.like('%$escaped%', escapeChar: '\\');
}
