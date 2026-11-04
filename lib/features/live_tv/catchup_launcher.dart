import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/parsers/xtream_client.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/playback_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';

/// Builds a catch-up stream URL for [programme] on [channel] and navigates
/// into the player, replacing the current route. Shared by [EpgPanel]
/// (single-channel bottom sheet) and the TV guide grid so both launch
/// catch-up playback identically instead of duplicating this logic.
///
/// [handBackTo], if given, is whoever should get the stream back when the
/// player closes on the live channel (the TV guide's preview pane) — so Go
/// Live, then Back, keeps the channel playing there.
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
/// Whoever receives the stream back when the player closes (the TV guide's
/// preview pane) and needs to know which channel/programme a catch-up URL is.
abstract interface class CatchupAware {
  void rememberCatchup(String url, Channel channel, Programme programme);
}

/// The catch-up stream URL for [programme], or null if the channel/source
/// can't do catch-up.
String? catchupUrlFor(Channel channel, Source source, Programme programme) {
  if (channel.streamId == null ||
      source.xtreamHost == null ||
      source.xtreamUsername == null ||
      source.xtreamPassword == null) {
    return null;
  }
  final client = XtreamClient.fromSource(source);
  final url = client.buildCatchupUrl(
      channel.streamId!, programme.start, programme.duration);
  client.dispose();
  return url;
}

Future<void> launchCatchup({
  required BuildContext context,
  required WidgetRef ref,
  required Channel channel,
  required Source source,
  required Programme programme,
  VoidCallback? dismiss,
  Object? handBackTo,
  bool replace = true,
}) async {
  if (channel.streamId == null ||
      source.xtreamHost == null ||
      source.xtreamUsername == null ||
      source.xtreamPassword == null) {
    return;
  }

  final client = XtreamClient.fromSource(source);
  final url = client.buildCatchupUrl(
      channel.streamId!, programme.start, programme.duration);
  client.dispose();
  if (handBackTo is CatchupAware) {
    handBackTo.rememberCatchup(url, channel, programme);
  }

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
    if (handBackTo != null) 'handBackTo': handBackTo,
  };
  unawaited(replace
      ? router.pushReplacement('/player', extra: extra)
      : router.push('/player', extra: extra));
}

/// Opens a channel from anywhere. On a catch-up channel with a show already
/// underway (and "Ask to Start Over" on), asks whether to start that show
/// from the beginning or watch live; otherwise just calls [playLive].
/// [programme] is what's airing, when the caller already knows it.
/// Returns true if it went to catch-up.
Future<bool> openChannelWithStartChoice({
  required BuildContext context,
  required WidgetRef ref,
  required Channel channel,
  required VoidCallback playLive,
  Programme? programme,
  Object? handBackTo,
  VoidCallback? beforeCatchup,
}) async {
  if (!ref.read(askStartOverProvider) ||
      !channel.hasCatchup ||
      channel.streamId == null) {
    playLive();
    return false;
  }
  final db = ref.read(appDatabaseProvider);
  final p = programme ?? await db.getCurrentProgramme(channel.id);
  final now = DateTime.now();
  // Only a show that's really underway, and still inside the provider's
  // catch-up window; a show that just began has nothing to start over.
  if (p == null ||
      !p.isLive ||
      now.difference(p.start) < const Duration(minutes: 2) ||
      now.difference(p.start) > Duration(days: channel.catchupDays)) {
    playLive();
    return false;
  }
  if (!context.mounted) return false;
  final startOver = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(p.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Text(
          "This show started ${_ago(now.difference(p.start))} ago. "
          'Where would you like to start?'),
      actions: [
        TextButton(
          autofocus: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Start from the beginning'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Watch live'),
        ),
      ],
    ),
  );
  // Dismissed (Back) = changed my mind: stay where I was.
  if (startOver == null) return false;
  if (!startOver) {
    playLive();
    return false;
  }
  final source = await db.getSourceById(channel.sourceId);
  if (source == null || !context.mounted) {
    playLive();
    return false;
  }
  beforeCatchup?.call();
  await launchCatchup(
    context: context,
    ref: ref,
    channel: channel,
    source: source,
    programme: p,
    handBackTo: handBackTo,
    replace: false,
  );
  return true;
}

String _ago(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes} minutes';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return m == 0 ? '$h hour${h == 1 ? '' : 's'}' : '${h}h ${m}m';
}
