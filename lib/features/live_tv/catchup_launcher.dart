import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/parsers/xtream_client.dart';
import 'package:open_iptv/core/services/playback_service.dart';

/// Builds a catch-up stream URL for [programme] on [channel] and navigates
/// into the player, replacing the current route. Shared by [EpgPanel]
/// (single-channel bottom sheet) and the TV guide grid so both launch
/// catch-up playback identically instead of duplicating this logic.
///
/// [dismiss], if given, runs first (e.g. popping a bottom sheet) before
/// navigating into the player.
///
/// [replace] controls whether that navigation is a pushReplacement (default
/// — required whenever a live PlayerScreen is still mounted underneath,
/// see below) or a plain push (when launched from a screen that isn't
/// itself a PlayerScreen, e.g. the TV guide grid, where there's no existing
/// player instance to race with and a plain push lets back-navigation
/// return to that screen instead of skipping past it).
Future<void> launchCatchup({
  required BuildContext context,
  required WidgetRef ref,
  required Channel channel,
  required Source source,
  required Programme programme,
  VoidCallback? dismiss,
  bool replace = true,
}) async {
  if (channel.streamId == null ||
      source.xtreamHost == null ||
      source.xtreamUsername == null ||
      source.xtreamPassword == null) {
    return;
  }

  final client = XtreamClient(
    host: source.xtreamHost!,
    username: source.xtreamUsername!,
    password: source.xtreamPassword!,
    sourceId: source.id,
  );
  final url = client.buildCatchupUrl(
      channel.streamId!, programme.start, programme.duration);
  client.dispose();

  final router = GoRouter.of(context);
  // pop() (via dismiss) only dismisses a sheet/overlay, leaving the
  // still-playing live PlayerScreen mounted underneath. pushReplacement()
  // disposes it first — pushing a second player screen on top instead would
  // mean two screens fighting over the single shared Player, so mpv's native
  // callback thread could fire into an object torn down mid-flight.
  //
  // markTransitioning() tells the outgoing live PlayerScreen's dispose()
  // (which runs after this pushReplacement, from a screen instance this
  // code has no direct reference to) to skip its normal stop()/orientation
  // reset — otherwise it undoes the catch-up screen's just-started playback
  // and landscape lock a moment after they're set.
  if (replace) ref.read(playbackServiceProvider).markTransitioning();
  dismiss?.call();
  final extra = {
    'streamUrl': url,
    'title': programme.title,
    'contentType': 'catchup',
    // Same key live playback uses for the channel id — keeps the EPG
    // guide button working in catch-up mode without a new field.
    'contentId': channel.id,
  };
  unawaited(replace
      ? router.pushReplacement('/player', extra: extra)
      : router.push('/player', extra: extra));
}
