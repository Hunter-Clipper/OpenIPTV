import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every translation file must have exactly the keys of the English template
/// and use the same `{placeholders}` in each message.
void main() {
  final dir = Directory('lib/l10n');

  Map<String, dynamic> load(File f) =>
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

  Map<String, String> messages(Map<String, dynamic> arb) => {
        for (final e in arb.entries)
          if (!e.key.startsWith('@') && e.value is String)
            e.key: e.value as String,
      };

  // `{name}` tokens at the top level and inside ICU plural/select branches.
  // ICU keywords (`count, plural, ...`) are skipped: only the variable names.
  Set<String> placeholders(String message) {
    final out = <String>{};
    // A brace right after a letter or digit opens an ICU branch (`other{…}`,
    // `Admin{…}`), whose body is plain text, not a placeholder.
    final simple =
        RegExp(r'(?<![A-Za-z0-9])\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*(?:,|\})');
    for (final m in simple.allMatches(message)) {
      out.add(m.group(1)!);
    }
    return out;
  }

  final english = messages(load(File('${dir.path}/app_en.arb')));
  final translations = dir
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'app_[A-Za-z_]+\.arb$').hasMatch(f.path))
      .where((f) => !f.path.endsWith('app_en.arb'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('there is at least one translation to compare', () {
    expect(translations, isNotEmpty);
  });

  for (final file in translations) {
    final name = file.uri.pathSegments.last;
    group(name, () {
      final other = messages(load(file));

      test('has no missing keys', () {
        final missing = english.keys.toSet().difference(other.keys.toSet());
        expect(missing, isEmpty, reason: 'missing from $name');
      });

      test('has no extra keys', () {
        final extra = other.keys.toSet().difference(english.keys.toSet());
        expect(extra, isEmpty, reason: 'not in app_en.arb');
      });

      test('uses the same placeholders as English', () {
        final bad = <String>[];
        for (final key in english.keys) {
          final t = other[key];
          if (t == null) continue;
          final a = placeholders(english[key]!);
          final b = placeholders(t);
          if (a.length != b.length || !a.containsAll(b)) {
            bad.add('$key: en=$a $name=$b');
          }
        }
        expect(bad, isEmpty);
      });
    });
  }
}
