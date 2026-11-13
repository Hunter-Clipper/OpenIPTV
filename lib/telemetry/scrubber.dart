// Scrubbing for anonymous reports (#150). Anything free-form goes through
// here before it is stored or sent. The rules are strict on purpose: when in
// doubt a line is dropped, never kept.

final _url = RegExp(r'[a-zA-Z][a-zA-Z0-9+.-]*://');
final _ipv4 = RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}\b');
final _ipv6 = RegExp(r'\b(?:[0-9a-fA-F]{1,4}:){2,7}[0-9a-fA-F]{1,4}\b');
final _email = RegExp(r'[^\s@]+@[^\s@]+\.[^\s@]+');
final _nativeLib = RegExp(r'^native lib[A-Za-z0-9_.+-]{1,60}\.so$');
final _typeName = RegExp(r'^[A-Za-z_][A-Za-z0-9_$.]*');

/// Most stack lines kept, and the longest one.
const maxStackLines = 30;
const maxLineLength = 200;

bool _looksPrivate(String s) =>
    _url.hasMatch(s) ||
    _ipv4.hasMatch(s) ||
    _ipv6.hasMatch(s) ||
    _email.hasMatch(s);

/// A stack line is kept only if it is code: a native library name, a Dart `package:` or `dart:`
/// frame, or a Java/Kotlin frame in an Android or OpenIPTV package. File
/// paths, URLs, addresses and anything else are dropped.
bool _isCodeFrame(String line) {
  // A native library name (`native libflutter.so`) from a native crash: the
  // library only, never a path.
  if (_nativeLib.hasMatch(line)) return true;
  final isDart = line.contains('package:') || line.contains('dart:');
  final isJvm = RegExp(r'^\s*(?:at\s+)?(?:com\.openiptv\.|androidx\.|android\.|'
          r'java\.|javax\.|kotlin\.|kotlinx\.|io\.flutter\.|com\.google\.android\.)')
      .hasMatch(line);
  return isDart || isJvm;
}

/// Reduces a raw stack trace to safe code lines.
List<String> scrubStack(String raw) {
  final out = <String>[];
  for (final line in raw.split('\n')) {
    final t = line.trim();
    if (t.isEmpty || !_isCodeFrame(t) || _looksPrivate(t)) continue;
    out.add(t.length > maxLineLength ? t.substring(0, maxLineLength) : t);
    if (out.length == maxStackLines) break;
  }
  return out;
}

/// The exception's class name: leading identifier only, no message, no
/// generics. Anything unrecognisable becomes `Unknown`.
String scrubErrorType(String raw) {
  final m = _typeName.firstMatch(raw.trim());
  final name = m?.group(0) ?? '';
  if (name.isEmpty || name.length > 80 || _looksPrivate(name)) return 'Unknown';
  return name;
}

/// Short descriptive text (app version, device model): printable, capped,
/// and never anything that looks like an address.
String scrubShortText(String raw) {
  final t = raw.replaceAll(RegExp(r'[^\x20-\x7E]'), '').trim();
  if (t.isEmpty || _looksPrivate(t)) return 'unknown';
  return t.length > 60 ? t.substring(0, 60) : t;
}
