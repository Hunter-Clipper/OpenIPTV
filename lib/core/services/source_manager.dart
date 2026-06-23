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

  /// Returns the detected source type without persisting anything.
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
      // Try HEAD first; fall back to GET if HEAD fails.
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
    await refreshSource(source, onProgress: onProgress);
    return source;
  }

  Future<void> refreshSource(Source source, {void Function(String)? onProgress}) async {
    if (source.type == SourceType.m3u) {
      await _refreshM3u(source, onProgress: onProgress);
    } else {
      await _refreshXtream(source, onProgress: onProgress);
    }
    await db.updateSourceRefreshTime(source.id, DateTime.now());
    onProgress?.call('Loading TV guide…');
    await epgService.refreshEpg(source, onProgress: onProgress);
  }

  /// Refreshes only live channels (and EPG) for a source.
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
    await epgService.refreshEpg(source);
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

  Future<void> _refreshM3u(Source source, {void Function(String)? onProgress}) async {
    final url = source.m3uUrl;
    if (url == null) return;

    onProgress?.call('Connecting to provider…');
    final response = await http.get(Uri.parse(url)).timeout(
          const Duration(seconds: 30),
        );
    if (response.statusCode != 200) {
      throw Exception('http_${response.statusCode}');
    }

    onProgress?.call('Parsing channels…');
    final result = await M3uParser.parse(response.body, source.id);

    // Auto-detect EPG URL from M3U header if not already set.
    if (source.epgUrl == null && result.epgUrl != null) {
      await db.upsertSource(source.copyWith(epgUrl: result.epgUrl));
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
  }

  // ---------------------------------------------------------------------------
  // Xtream refresh
  // ---------------------------------------------------------------------------

  Future<void> _refreshXtream(Source source, {void Function(String)? onProgress}) async {
    final client = XtreamClient(
      host: source.xtreamHost!,
      username: source.xtreamUsername!,
      password: source.xtreamPassword!,
      sourceId: source.id,
    );

    try {
      onProgress?.call('Connecting to provider…');
      await db.deleteChannelsForSource(source.id);
      await db.deleteMoviesForSource(source.id);
      await db.deleteSeriesForSource(source.id);
      await db.deleteEpisodesForSource(source.id);

      onProgress?.call('Fetching channels…');
      final channels = await client.getLiveStreams();
      if (channels.isNotEmpty) await db.upsertChannels(channels);

      onProgress?.call('Fetching movies…');
      final movies = await client.getVodStreams();
      if (movies.isNotEmpty) await db.upsertMovies(movies);

      onProgress?.call('Fetching series…');
      final seriesList = await client.getAllSeries();
      if (seriesList.isNotEmpty) await db.upsertSeries(seriesList);

      // Episodes are fetched lazily (per-series) to avoid hammering the API.
    } finally {
      client.dispose();
    }
  }
}
