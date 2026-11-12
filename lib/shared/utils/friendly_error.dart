import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/local_playlists.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/l10n/gen/app_localizations_en.dart';

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
///
/// Pass [l10n] (from `AppLocalizations.of(context)`) to get the message in the
/// app language. Callers with no [BuildContext] (services) may leave it out
/// and get English.
String friendlySourceErrorMessage(Object error, [AppLocalizations? l10n]) {
  final t = l10n ?? AppLocalizationsEn();
  final msg = error.toString();
  if (error is LocalPlaylistException) {
    return switch (error.code) {
      'not_m3u' => t.errorPlaylistNotM3u,
      'empty' => t.errorPlaylistEmpty,
      _ => t.errorPlaylistFileMissing,
    };
  }
  if (error is SourceEditException) {
    return switch (error.code) {
      'xtream_login' => t.errorXtreamLogin,
      'm3u_missing' => t.errorM3uMissing,
      _ => t.errorLinkOpenFailed,
    };
  }
  if (_isTimeout(error)) {
    return t.errorPlaylistTimeout;
  }
  if (msg.contains('http_401') || msg.contains('http_403')) {
    return t.errorBadCredentials;
  } else if (error is SocketException ||
      // package:http wraps socket failures (e.g. DNS lookup) in a
      // ClientException whose message never mentions SocketException.
      error is http.ClientException) {
    return t.errorUnreachable;
  } else if (RegExp(r'http_5\d\d').hasMatch(msg)) {
    // The provider's own server failed — the link and login are fine.
    return t.errorProviderServer;
  } else if (msg.contains('http_')) {
    return t.errorInvalidLink;
  }
  return t.errorGeneric;
}

/// Maps a raw exception thrown while refreshing a TV guide into a
/// user-friendly message. EPG failures are common (large files, slow
/// servers) and the user should know the guide specifically failed —
/// not the whole playlist. [l10n] works as in [friendlySourceErrorMessage].
String friendlyEpgErrorMessage(Object error, [AppLocalizations? l10n]) {
  final t = l10n ?? AppLocalizationsEn();
  if (_isTimeout(error)) {
    return t.errorGuideTimeout;
  }
  final msg = error.toString();
  if (msg.contains('empty_guide')) {
    return t.errorGuideEmpty;
  }
  if (msg.contains('http_401') || msg.contains('http_403')) {
    return t.errorGuideLogin;
  } else if (error is SocketException || error is http.ClientException) {
    return t.errorGuideUnreachable;
  } else if (RegExp(r'http_5\d\d').hasMatch(msg)) {
    return t.errorGuideServer;
  } else if (msg.contains('http_')) {
    return t.errorGuideInvalidLink;
  }
  return t.errorGuideGeneric;
}
