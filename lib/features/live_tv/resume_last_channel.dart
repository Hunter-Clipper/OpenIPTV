// "Open Last Channel on Start": when the app opens, go straight to the live
// channel that was watched last (Settings → Playback).

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/channel_customisation.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/player/player_screen.dart';
import 'package:open_iptv/telemetry/consent.dart';

// Once per app launch: coming back from the background must not restart a
// channel the person has since closed.
bool _tried = false;

/// Opens the last watched channel of the active profile, if the setting is on.
///
/// Quietly does nothing when there is no history, the channel is in a hidden
/// or locked category (or adult on a kids profile), something is already
/// playing, or the one-time crash-report question still has to be answered
/// (it would end up behind the player).
Future<void> resumeLastChannelOnStart(
    BuildContext context, ProviderContainer container) async {
  if (_tried) return;
  final prefs = await container.read(appPreferencesProvider.future);
  if (!prefs.lastChannelOnStart) {
    _tried = true;
    return;
  }
  final profile = await container.read(activeProfileProvider.future);
  // No profile yet (the picker is still up): try again on the next call.
  if (profile == null) return;
  _tried = true;
  if (await readStatsChoice() == StatsChoice.unset) return;

  final recent = await container
      .read(appDatabaseProvider)
      .watchRecentChannels(profile.id,
          limit: 1, sourceId: container.read(activeSourceIdProvider))
      .first;
  if (recent.isEmpty) return;
  final channel = recent.first;

  // A channel this profile hid is not reopened at start either.
  if (container.read(channelCustomProvider).hidden.contains(channel.id)) return;
  final hidden = profile.hiddenCategories.toSet();
  final categories = channel.categories;
  if (categories.any(hidden.contains)) return;
  if (isLockedContent(categories, prefs)) return;
  if (profile.isKidsProfile && categories.any(isAdultCategory)) return;

  if (!context.mounted || PlayerScreen.openCount > 0) return;
  await context.push('/player', extra: {
    'streamUrl': channel.streamUrl,
    'title': container.read(channelCustomProvider).names[channel.id] ?? channel.name,
    'contentType': 'live',
    'contentId': channel.id,
  });
}
