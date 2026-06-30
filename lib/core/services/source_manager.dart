import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/parsers/m3u_parser.dart';
import 'package:open_iptv/core/parsers/xtream_client.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'source_manager.g.dart';

const _uuid = Uuid();

enum SourceDetectionResult { m3u, xtream, failed }

@Riverpod(keepAlive: true)
SourceManager sourceManager(SourceManagerRef ref) {
  return SourceManager(
    db: ref.watch(appDatabaseProvider),
    epgService: ref.watch(epgServiceProvider),
  );
}

@Riverpod(keepAlive: true)
Future<List<Source>> allSources(AllSourcesRef ref) {
  return ref.watch(appDatabaseProvider).getAllSources();
}

class SourceManager {
  const SourceManager({required this.db, required this.epgService});

  final AppDatabase db;
  final EpgService epgService;

  // ---------------------------------------------------------------------------
  // Auto-detection
  // ---------------------------------------------------------------------------

  Future<SourceDetectionResult> detectSourceType({
    String? url,
    String? xtreamHost,
    String? username,
    String? password,
  }) async {
    if (xtreamHost != null && username != null && password != null) {
      final client = XtreamClient(
        host: xtreamHost,
        username: username,
        password: password,
        sourceId: '',
      );
      final valid = await client.validate();
      client.dispose();
      return valid ? SourceDetectionResult.xtream : SourceDetectionResult.failed;
    }

    if (url != null && url.isNotEmpty) {
      final result = await _probeM3u(url);
      return result ? SourceDetectionResult.m3u : SourceDetectionResult.failed;
    }

    return SourceDetectionResult.failed;
  }

  Future<bool> _probeM3u(String url) async {
    try {
      final uri = Uri.parse(url);
      var response = await http.head(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        response = await http.get(uri).timeout(const Duration(seconds: 10));
      }
      if (response.statusCode != 200) return false;
      final body = response.body.trimLeft();
      return body.startsWith('#EXTM3U');
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Add / refresh / remove
  // ---------------------------------------------------------------------------

  Future<Source> addSource({
    required String nickname,
    required SourceType type,
    String? m3uUrl,
    String? xtreamHost,
    String? xtreamUsername,
    String? xtreamPassword,
    String? epgUrl,
    void Function(String)? onProgress,
  }) async {
    final source = Source(
      id: _uuid.v4(),
      nickname: nickname,
      type: type,
      m3uUrl: m3uUrl,
      xtreamHost: xtreamHost,
      xtreamUsername: xtreamUsername,
      xtreamPassword: xtreamPassword,
      epgUrl: epgUrl,
    );

    await db.upsertSource(source);
    try {
      await refreshSource(source, onProgress: onProgress);
    } catch (e) {
      // Fetch/parse failed — remove the orphaned source entry so the user
      // doesn't see a broken playlist in their list.
      await deleteSource(source.id);
      rethrow;
    }
    return source;
  }

  /// Full refresh: playlist (channels/movies/series) then EPG fires in background.
  Future<void> refreshSource(Source source, {void Function(String)? onProgress}) async {
    Source updated;
    if (source.type == SourceType.m3u) {
      updated = await _refreshM3u(source, onProgress: onProgress);
    } else {
      updated = await _refreshXtream(source, onProgress: onProgress);
    }
    await db.updateSourceRefreshTime(source.id, DateTime.now());
    // Pass the updated source so the auto-set EPG URL is included.
    unawaited(epgService.refreshEpg(updated));
  }

  /// Refreshes only the playlist (channels/movies/series) — no EPG.
  /// Used by the "Refresh Playlist" button in Settings.
  Future<void> refreshPlaylist(Source source) async {
    if (source.type == SourceType.m3u) {
      await _refreshM3u(source);
    } else {
      await _refreshXtream(source);
    }
    await db.updateSourceRefreshTime(source.id, DateTime.now());
  }


  /// Refreshes only the EPG for a source.
  /// Used by the "Refresh TV Guide" button in Settings.
  Future<void> refreshEpgOnly(Source source) async {
    await epgService.refreshEpg(source);
  }

  /// Refreshes only live channels then EPG in background (for Live TV pull-to-refresh).
  Future<void> refreshChannels(Source source) async {
    if (source.type == SourceType.m3u) {
      final url = source.m3uUrl;
      if (url == null) return;
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw Exception('http_${response.statusCode}');
      final result = await M3uParser.parse(response.body, source.id);
      if (source.epgUrl == null && result.epgUrl != null) {
        await db.upsertSource(source.copyWith(epgUrl: result.epgUrl));
      }
      await db.deleteChannelsForSource(source.id);
      if (result.channels.isNotEmpty) await db.upsertChannels(result.channels);
    } else {
      final client = XtreamClient(
        host: source.xtreamHost!,
        username: source.xtreamUsername!,
        password: source.xtreamPassword!,
        sourceId: source.id,
      );
      try {
        await db.deleteChannelsForSource(source.id);
        final channels = await client.getLiveStreams();
        if (channels.isNotEmpty) await db.upsertChannels(channels);
      } finally {
        client.dispose();
      }
    }
    await db.updateSourceRefreshTime(source.id, DateTime.now());
    unawaited(epgService.refreshEpg(source));
  }

  /// Refreshes only movies for a source.
  Future<void> refreshMovies(Source source) async {
    if (source.type == SourceType.m3u) {
      final url = source.m3uUrl;
      if (url == null) return;
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw Exception('http_${response.statusCode}');
      final result = await M3uParser.parse(response.body, source.id);
      await db.deleteMoviesForSource(source.id);
      if (result.movies.isNotEmpty) await db.upsertMovies(result.movies);
    } else {
      final client = XtreamClient(
        host: source.xtreamHost!,
        username: source.xtreamUsername!,
        password: source.xtreamPassword!,
        sourceId: source.id,
      );
      try {
        await db.deleteMoviesForSource(source.id);
        final movies = await client.getVodStreams();
        if (movies.isNotEmpty) await db.upsertMovies(movies);
      } finally {
        client.dispose();
      }
    }
    await db.updateSourceRefreshTime(source.id, DateTime.now());
  }

  /// Refreshes only series for a source.
  Future<void> refreshSeries(Source source) async {
    if (source.type == SourceType.m3u) {
      final url = source.m3uUrl;
      if (url == null) return;
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) throw Exception('http_${response.statusCode}');
      final result = await M3uParser.parse(response.body, source.id);
      await db.deleteSeriesForSource(source.id);
      if (result.series.isNotEmpty) await db.upsertSeries(result.series);
    } else {
      final client = XtreamClient(
        host: source.xtreamHost!,
        username: source.xtreamUsername!,
        password: source.xtreamPassword!,
        sourceId: source.id,
      );
      try {
        await db.deleteSeriesForSource(source.id);
        final seriesList = await client.getAllSeries();
        if (seriesList.isNotEmpty) await db.upsertSeries(seriesList);
      } finally {
        client.dispose();
      }
    }
    await db.updateSourceRefreshTime(source.id, DateTime.now());
  }

  // Fetches episodes for a single series on demand (Xtream only).
  // Called lazily from the series detail screen the first time a series is opened.
  Future<void> fetchEpisodesForSeries(String seriesId, String sourceId) async {
    final source = await db.getSourceById(sourceId);
    if (source == null || source.type != SourceType.xtream) return;
    // App internal ID format: "${sourceId}_ser_${xtreamSeriesId}"
    final xtreamId = seriesId.replaceFirst('${sourceId}_ser_', '');
    final client = XtreamClient(
      host: source.xtreamHost!,
      username: source.xtreamUsername!,
      password: source.xtreamPassword!,
      sourceId: sourceId,
    );
    try {
      final episodes = await client.getSeriesEpisodes(xtreamId);
      if (episodes.isNotEmpty) await db.upsertEpisodes(episodes);
    } finally {
      client.dispose();
    }
  }

  Future<void> deleteSource(String sourceId) async {
    await db.deleteChannelsForSource(sourceId);
    await db.deleteMoviesForSource(sourceId);
    await db.deleteSeriesForSource(sourceId);
    await db.deleteEpisodesForSource(sourceId);
    await db.deleteSource(sourceId);
  }

  // ---------------------------------------------------------------------------
  // M3U refresh
  // ---------------------------------------------------------------------------

  Future<Source> _refreshM3u(Source source, {void Function(String)? onProgress}) async {
    final url = source.m3uUrl;
    if (url == null) return source;

    onProgress?.call('Connecting to provider…');
    final response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 30),
        );
    if (response.statusCode != 200) {
      throw Exception('http_${response.statusCode}');
    }

    onProgress?.call('Parsing channels…');
    final result = await M3uParser.parse(response.body, source.id);

    Source updated = source;
    if (source.epgUrl == null && result.epgUrl != null) {
      updated = source.copyWith(epgUrl: result.epgUrl);
      await db.upsertSource(updated);
    }

    onProgress?.call('Saving to database…');
    await db.deleteChannelsForSource(source.id);
    await db.deleteMoviesForSource(source.id);
    await db.deleteSeriesForSource(source.id);
    await db.deleteEpisodesForSource(source.id);

    if (result.channels.isNotEmpty) await db.upsertChannels(result.channels);
    if (result.movies.isNotEmpty) await db.upsertMovies(result.movies);
    if (result.series.isNotEmpty) await db.upsertSeries(result.series);
    if (result.episodes.isNotEmpty) await db.upsertEpisodes(result.episodes);
    return updated;
  }

  // ---------------------------------------------------------------------------
  // Xtream refresh
  // ---------------------------------------------------------------------------

  Future<Source> _refreshXtream(Source source, {void Function(String)? onProgress}) async {
    final client = XtreamClient(
      host: source.xtreamHost!,
      username: source.xtreamUsername!,
      password: source.xtreamPassword!,
      sourceId: source.id,
    );

    // Auto-set XMLTV EPG URL for Xtream sources if not already configured.
    Source updated = source;
    if (source.epgUrl == null || source.epgUrl!.isEmpty) {
      final host = source.xtreamHost!.endsWith('/')
          ? source.xtreamHost!
          : '${source.xtreamHost!}/';
      final epgUrl =
          '${host}xmltv.php?username=${source.xtreamUsername}&password=${source.xtreamPassword}';
      updated = source.copyWith(epgUrl: epgUrl);
      await db.upsertSource(updated);
    }

    try {
      onProgress?.call('Connecting to provider…');
      await db.deleteChannelsForSource(source.id);
      await db.deleteMoviesForSource(source.id);
      await db.deleteSeriesForSource(source.id);
      await db.deleteEpisodesForSource(source.id);

      onProgress?.call('Fetching channels…');
      var t = DateTime.now();
      final channels = await client.getLiveStreams();
      debugPrint('[Source] channels: ${channels.length} in ${DateTime.now().difference(t).inMilliseconds}ms');
      if (channels.isNotEmpty) {
        onProgress?.call('Saving ${channels.length} channels…');
        await db.upsertChannels(channels);
      }

      onProgress?.call('Fetching movies…');
      t = DateTime.now();
      final movies = await client.getVodStreams();
      debugPrint('[Source] movies: ${movies.length} in ${DateTime.now().difference(t).inMilliseconds}ms');
      if (movies.isNotEmpty) {
        onProgress?.call('Saving ${movies.length} movies…');
        await db.upsertMovies(movies);
      }

      onProgress?.call('Fetching series…');
      t = DateTime.now();
      final seriesList = await client.getAllSeries();
      debugPrint('[Source] series: ${seriesList.length} in ${DateTime.now().difference(t).inMilliseconds}ms');
      if (seriesList.isNotEmpty) {
        onProgress?.call('Saving ${seriesList.length} series…');
        await db.upsertSeries(seriesList);
      }
    } finally {
      client.dispose();
    }
    return updated;
  }
}
