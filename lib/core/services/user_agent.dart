/// The user agent a stream request identifies itself with. Providers tell
/// connections apart by IP address plus user agent (#52), and a few only
/// accept the strings of known players, so Power User Tools lets people
/// replace the app's own.
///
/// Returns the cleaned custom string, or null for "use the app's own" (blank
/// input). Throws [FormatException] for something that can't go into an HTTP
/// header: line breaks, control characters, anything outside plain ASCII, or
/// more than [maxUserAgentLength] characters.
const maxUserAgentLength = 200;

String? parseCustomUserAgent(String? input) {
  final text = input?.trim() ?? '';
  if (text.isEmpty) return null;
  if (text.length > maxUserAgentLength) {
    throw const FormatException('Keep it under 200 characters.');
  }
  for (final unit in text.codeUnits) {
    if (unit < 0x20 || unit > 0x7e) {
      throw const FormatException(
          'Use plain letters, numbers and symbols only, on one line.');
    }
  }
  return text;
}
