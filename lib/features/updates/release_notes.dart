import 'package:flutter/material.dart';

/// Renders a GitHub release body — the small subset of Markdown our release
/// notes use: `#`/`##` headings, `-`/`*` bullets, `>` quotes, **bold**,
/// `code`, and [links](url) (shown as their text). Kept dependency-free on
/// purpose; anything fancier degrades to plain text.
class ReleaseNotes extends StatelessWidget {
  const ReleaseNotes(this.markdown, {super.key});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = theme.textTheme.bodyMedium!;
    final children = <Widget>[];
    for (final raw in markdown.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) {
        children.add(const SizedBox(height: 8));
      } else if (trimmed.startsWith('#')) {
        final text = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
        children.add(Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text.rich(
            _inline(text, body.copyWith(fontWeight: FontWeight.w700,
                fontSize: (body.fontSize ?? 14) + 1)),
          ),
        ));
      } else if (RegExp(r'^[-*]\s+').hasMatch(trimmed)) {
        final text = trimmed.replaceFirst(RegExp(r'^[-*]\s+'), '');
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, left: 2),
                child: Text('•', style: body.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700)),
              ),
              Expanded(child: Text.rich(_inline(text, body))),
            ],
          ),
        ));
      } else if (trimmed.startsWith('>')) {
        final text = trimmed.replaceFirst(RegExp(r'^>\s*'), '');
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(_inline(text,
              body.copyWith(color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic))),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text.rich(_inline(trimmed, body)),
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  static final _link = RegExp(r'\[([^\]]+)\]\([^)]*\)');
  static final _bold = RegExp(r'\*\*(.+?)\*\*');

  /// Links → their text, `code` → plain, **bold** → bold spans.
  static TextSpan _inline(String text, TextStyle style) {
    final plain =
        text.replaceAllMapped(_link, (m) => m.group(1)!).replaceAll('`', '');
    final spans = <TextSpan>[];
    var i = 0;
    for (final m in _bold.allMatches(plain)) {
      if (m.start > i) spans.add(TextSpan(text: plain.substring(i, m.start)));
      spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700)));
      i = m.end;
    }
    if (i < plain.length) spans.add(TextSpan(text: plain.substring(i)));
    return TextSpan(style: style, children: spans);
  }
}
