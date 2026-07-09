/// Maps a raw exception thrown while adding/refreshing an IPTV source into
/// a single canonical user-friendly message. Used by both onboarding flows
/// and the Settings source-refresh actions, which all hit the same class of
/// failure (bad credentials, unreachable server, malformed URL) — kept in one
/// place so the wording can't drift between call sites again.
String friendlySourceErrorMessage(Object error) {
  final msg = error.toString();
  if (msg.contains('http_401') || msg.contains('http_403')) {
    return "Your username or password doesn't seem right. Check with your provider.";
  } else if (msg.contains('timeout') || msg.contains('SocketException')) {
    return "Couldn't reach this server. Check your internet connection and try again.";
  } else if (msg.contains('http_')) {
    return "This link doesn't look like a valid channel list. Check the URL with your provider.";
  }
  return 'Something went wrong. Check your details and try again.';
}
