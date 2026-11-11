import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/channel_customisation.dart';
import 'package:open_iptv/core/services/profile_service.dart';

/// All channels for the active source (or every source if none is
/// selected), scoped to the active profile's favorites/watch-progress data.
/// Shared by the Live TV list/grid screens and the TV guide grid so both
/// read from the same source-of-truth stream rather than duplicating this
/// query.
final allChannelsProvider = StreamProvider<List<Channel>>((ref) {
  final activeSourceId = ref.watch(activeSourceIdProvider);
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  // Channels this profile hid (hold OK → Hide channel) leave every list.
  final hidden = ref.watch(channelCustomProvider.select((c) => c.hidden));
  final source = activeSourceId != null
      ? db.watchChannelsForSource(activeSourceId, profileId: profileId)
      : db.watchAllChannels(profileId: profileId);
  if (hidden.isEmpty) return source;
  return source.map((list) => [
        for (final c in list)
          if (!hidden.contains(c.id)) c,
      ]);
});
