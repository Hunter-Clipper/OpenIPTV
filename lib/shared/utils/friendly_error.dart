import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_iptv/core/storage/local_playlists.dart';

/// Maps a raw exception thrown while adding/refreshing an IPTV source into
/// a single canonical user-friendly message. Used by both onboarding flows
/// and the Settings source-refresh actions, which all hit the same class of
/// failure (bad credentials, unreachable server, malformed URL) — kept in one
/// place so the wording can't drift between call sites again.
String friendlySourceErrorMessage(Object error) {
  final msg = error.toString();
  if (error is LocalPlaylistException) {
    return switch (error.code) {
      'not_m3u' => "This file isn't a playlist. Choose an .m3u or .m3u8 "
          'file from your provider.',
      'empty' => "This playlist file doesn't have any channels in it.",
      _ => "The playlist file is no longer on this device. Remove this "
          'playlist and add the file again.',
    };
  }
  if (msg.contains('http_401') || msg.contains('http_403')) {
    return "Your username or password doesn't seem right. Check with your provider.";
  } else if (error is TimeoutException ||
      error is SocketException ||
      // package:http wraps socket failures (e.g. DNS lookup) in a
      // ClientException whose message never mentions SocketException.
      error is http.ClientException) {
    return "Couldn't reach this server. Check your internet connection and try again.";
  } else if (msg.contains('http_')) {
    return "This link doesn't look like a valid channel list. Check the URL with your provider.";
  }
  return 'Something went wrong. Check your details and try again.';
}
