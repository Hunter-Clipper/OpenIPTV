import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/episode.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/models/series.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/utils/display_name.dart';

/// Publishes a read-only cache of OpenIPTV's own queues for the EDTV launcher.
/// OpenIPTV's database remains the source of truth; EDTV only polls this snapshot.
class EdtvQueueBridge {
  static const MethodChannel _channel = MethodChannel('openiptv/edtv');

  /// Remove a playlist's leading country marker from the display label only.
  /// The stored channel name remains untouched for matching and playback.
  static String _stripCountryPrefix(String name) {
    return name
        .replaceFirst(
          RegExp(
            r'^\s*(?:\[[A-Z]{2,3}\]|\(?[A-Z]{2,3}\)?)\s*[:|–—-]\s*',
            caseSensitive: true,
          ),
          '',
        )
        .trim();
  }

  static Future<void> clear() async {
    final snapshot = jsonEncode({
      'apiVersion': 1,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'continue': <Object>[],
      'channels': <Object>[],
    });
    try {
      await _channel.invokeMethod<void>('publishQueueSnapshot', snapshot);
    } catch (error) {
      debugPrint('[OTV-edtv] empty queue snapshot failed: $error');
    }
  }

  static Future<void> publishForProfile(
    AppDatabase db,
    String profileId,
    AppPreferences prefs,
  ) async {
    final profile = await db.getProfileById(profileId);
    if (profile == null) {
      await clear();
      return;
    }
    await publish(db, profile, prefs);
  }

  static Future<void> publish(
    AppDatabase db,
    Profile profile,
    AppPreferences prefs,
  ) async {
    try {
      final movies = await db.watchMoviesInProgress(profile.id).first;
      final episodes = await db.watchEpisodesInProgress(profile.id).first;
      final channels = await db
          .watchRecentChannels(profile.id,
              limit: 20, sourceId: prefs.activeSourceId)
          .first;
      final activeSourceId = prefs.activeSourceId;

      final seriesById = <String, Series>{};
      for (final episode in episodes) {
        if (!seriesById.containsKey(episode.seriesId)) {
          final series = await db.getSeriesById(episode.seriesId);
          if (series != null) seriesById[episode.seriesId] = series;
        }
      }

      final items = <Map<String, Object?>>[];
      for (final Movie movie in movies) {
        if (!movie.isInProgress ||
            (activeSourceId != null && movie.sourceId != activeSourceId) ||
            isLockedContent(splitGenres(movie.genre), prefs) ||
            (profile.isKidsProfile && isAdultGenre(movie.genre))) {
          continue;
        }
        items.add({
          'id': movie.id,
          'type': 'movie',
          'title': cleanDisplayName(movie.title),
          'subtitle': movie.year ?? '',
          'artwork': movie.posterUrl ?? '',
          'positionMs': movie.watchedDuration?.inMilliseconds ?? 0,
          'durationMs': movie.totalDuration?.inMilliseconds ?? 0,
          'timestamp': movie.lastWatchedAt?.millisecondsSinceEpoch ?? 0,
        });
      }
      for (final Episode episode in episodes) {
        final series = seriesById[episode.seriesId];
        if (!episode.isInProgress ||
            (activeSourceId != null && episode.sourceId != activeSourceId) ||
            (series != null &&
                (isLockedContent(splitGenres(series.genre), prefs) ||
                    (profile.isKidsProfile && isAdultGenre(series.genre))))) {
          continue;
        }
        // Match Jellyfin's episode-card layout: the series is the main title,
        // while the episode name and SxxExx identifier sit on the second line.
        final episodeTitle = episode.displayTitle;
        final seriesTitle =
            series == null ? '' : cleanDisplayName(series.title);
        items.add({
          'id': episode.id,
          'type': 'episode',
          'seriesId': episode.seriesId,
          'title': seriesTitle.isEmpty ? episodeTitle : seriesTitle,
          'subtitle': '$episodeTitle · ${episode.episodeLabel}',
          'artwork': series?.posterUrl ?? '',
          'positionMs': episode.watchedDuration?.inMilliseconds ?? 0,
          'durationMs': episode.totalDuration?.inMilliseconds ?? 0,
          'timestamp': episode.lastWatchedAt?.millisecondsSinceEpoch ?? 0,
        });
      }
      items.sort((a, b) => ((b['timestamp'] as int?) ?? 0)
          .compareTo((a['timestamp'] as int?) ?? 0));

      final recentChannels = <Map<String, Object?>>[];
      for (final Channel channel in channels) {
        if (isLockedContent(channel.categories, prefs) ||
            (profile.isKidsProfile && isAdultGenre(channel.groupTitle))) {
          continue;
        }
        recentChannels.add({
          'id': channel.id,
          'type': 'live',
          'title': _stripCountryPrefix(channel.name),
          'subtitle': 'Live',
          'artwork': channel.logoUrl ?? '',
          'tvgId': channel.tvgId ?? '',
          'tvgName': channel.tvgName ?? '',
          'positionMs': 0,
          'durationMs': 0,
          'timestamp': channel.lastWatchedAt?.millisecondsSinceEpoch ?? 0,
        });
      }

      final snapshot = jsonEncode({
        'apiVersion': 1,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
        'continue': items.take(20).toList(),
        'channels': recentChannels.take(20).toList(),
      });
      await _channel.invokeMethod<void>('publishQueueSnapshot', snapshot);
    } catch (error, stack) {
      debugPrint('[OTV-edtv] queue snapshot failed: $error');
      debugPrintStack(stackTrace: stack);
    }
  }
}
