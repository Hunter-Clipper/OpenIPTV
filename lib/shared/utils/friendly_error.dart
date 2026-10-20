import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/local_playlists.dart';

/// Whether [error] represents a timeout — either a Dart [TimeoutException]
/// or an HTTP client timeout (which surfaces as a [ClientException] with
/// "TimeoutException" in its message).
bool _isTimeout(Object error) {
  if (error is TimeoutException) return true;
  final msg = error.toString().toLowerCase();
  return msg.contains('timeout') || msg.contains('timed out');
}

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
  if (error is SourceEditException) {
    return switch (error.code) {
      'xtream_login' => "Couldn't sign in with these details. Check the "
          'server address, username and password with your provider.',
      'm3u_missing' => 'Enter the playlist link from your provider.',
      _ => "Couldn't open this playlist link. Check it with your provider.",
    };
  }
  if (_isTimeout(error)) {
    return "This playlist is taking too long to load. Check your internet "
        'connection and try again.';
  }
  if (msg.contains('http_401') || msg.contains('http_403')) {
    return "Your username or password doesn't seem right. Check with your provider.";
  } else if (error is SocketException ||
      // package:http wraps socket failures (e.g. DNS lookup) in a
      // ClientException whose message never mentions SocketException.
      error is http.ClientException) {
    return "Couldn't reach this server. Check your internet connection and try again.";
  } else if (RegExp(r'http_5\d\d').hasMatch(msg)) {
    // The provider's own server failed — the link and login are fine.
    return "The provider's server is having trouble right now. Try again later.";
  } else if (msg.contains('http_')) {
    return "This link doesn't look like a valid channel list. Check the URL with your provider.";
  }
  return 'Something went wrong. Check your details and try again.';
}

/// Maps a raw exception thrown while refreshing a TV guide into a
/// user-friendly message. EPG failures are common (large files, slow
/// servers) and the user should know the guide specifically failed —
/// not the whole playlist.
String friendlyEpgErrorMessage(Object error) {
  if (_isTimeout(error)) {
    return "The TV guide is taking too long to load. Check your internet "
        'connection and try again.';
  }
  final msg = error.toString();
  if (msg.contains('http_401') || msg.contains('http_403')) {
    return "The TV guide link needs a login. Check the guide URL with your provider.";
  } else if (error is SocketException || error is http.ClientException) {
    return "Couldn't reach the TV guide server. Check your internet connection "
        'and try again.';
  } else if (RegExp(r'http_5\d\d').hasMatch(msg)) {
    return "The TV guide server is having trouble right now. Try again later.";
  } else if (msg.contains('http_')) {
    return "This TV guide link doesn't look valid. Check the URL with your provider.";
  }
  return "The TV guide couldn't be loaded. Check your details and try again.";
}
