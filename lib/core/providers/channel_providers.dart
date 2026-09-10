import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/profile_service.dart';

/// All channels for the active source (or every source if none is
/// selected), scoped to the active profile's favorites/watch-progress data.
/// Shared by the Live TV list/grid screens and the TV guide grid so both
/// read from the same source-of-truth stream rather than duplicating this
/// query.
final allChannelsProvider = StreamProvider<List<Channel>>((ref) {
  final activeSourceId = ref.watch(activeSourceIdProvider);
  final db = ref.watch(appDatabaseProvider);
  final profileId =
      ref.watch(activeProfileProvider.select((a) => a.valueOrNull?.id));
  if (activeSourceId != null) {
    return db.watchChannelsForSource(activeSourceId, profileId: profileId);
  }
  return db.watchAllChannels(profileId: profileId);
});
