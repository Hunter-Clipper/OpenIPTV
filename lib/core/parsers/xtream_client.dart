import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/episode.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/models/series.dart';

class XtreamException implements Exception {
  const XtreamException(this.message);
  final String message;
  @override
  String toString() => 'XtreamException: $message';
}

class XtreamCategory {
  const XtreamCategory({required this.id, required this.name});
  final String id;
  final String name;
}

class XtreamClient {
  XtreamClient({
    required this.host,
    required this.username,
    required this.password,
    required this.sourceId,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final String host;
  final String username;
  final String password;
  final String sourceId;
  final http.Client _http;

  static const _timeout = Duration(seconds: 15);

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  /// Returns true if the server responds to the Xtream API.
  Future<bool> validate() async {
    try {
      await _get({'action': 'get_live_categories'});
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Live TV
  // ---------------------------------------------------------------------------

  Future<List<XtreamCategory>> getLiveCategories() async {
    final data = await _get({'action': 'get_live_categories'});
    return _parseCategories(data);
  }

  Future<List<Channel>> getLiveStreams({String? categoryId}) async {
    final params = {'action': 'get_live_streams'};
    if (categoryId != null) params['category_id'] = categoryId;
    final data = await _get(params);
    return _parseChannels(data);
  }

  // ---------------------------------------------------------------------------
  // VOD
  // ---------------------------------------------------------------------------

  Future<List<XtreamCategory>> getVodCategories() async {
    final data = await _get({'action': 'get_vod_categories'});
    return _parseCategories(data);
  }

  Future<List<Movie>> getVodStreams({String? categoryId}) async {
    final params = {'action': 'get_vod_streams'};
    if (categoryId != null) params['category_id'] = categoryId;
    final data = await _get(params);
    return _parseMovies(data);
  }

  Future<Map<String, dynamic>> getVodInfo(String vodId) async {
    return _get({'action': 'get_vod_info', 'vod_id': vodId});
  }

  // ---------------------------------------------------------------------------
  // Series
  // ---------------------------------------------------------------------------

  Future<List<XtreamCategory>> getSeriesCategories() async {
    final data = await _get({'action': 'get_series_categories'});
    return _parseCategories(data);
  }

  Future<List<Series>> getAllSeries({String? categoryId}) async {
    final params = {'action': 'get_series'};
    if (categoryId != null) params['category_id'] = categoryId;
    final data = await _get(params);
    return _parseSeries(data);
  }

  Future<List<Episode>> getSeriesEpisodes(String seriesId) async {
    final info = await _get({'action': 'get_series_info', 'series_id': seriesId});
    return _parseEpisodes(info, seriesId);
  }

  // ---------------------------------------------------------------------------
  // EPG
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getShortEpg(
    String streamId, {
    int limit = 5,
  }) async {
    final data = await _get({
      'action': 'get_short_epg',
      'stream_id': streamId,
      'limit': '$limit',
    });
    final epg = data['epg_listings'];
    if (epg == null) return [];
    return List<Map<String, dynamic>>.from(epg as List);
  }

  // ---------------------------------------------------------------------------
  // Stream URL builder
  // ---------------------------------------------------------------------------

  String buildStreamUrl(String streamId, String type, {String ext = 'ts'}) {
    final base = host.endsWith('/') ? host : '$host/';
    return '${base}$type/$username/$password/$streamId.$ext';
  }

  // ---------------------------------------------------------------------------
  // HTTP
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _get(Map<String, String> action) async {
    final uri = Uri.parse(host.endsWith('/') ? host : '$host/').replace(
      path: '/player_api.php',
      queryParameters: {
        'username': username,
        'password': password,
        ...action,
      },
    );

    final response = await _http.get(uri).timeout(_timeout);

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const XtreamException('auth_failed');
    }
    if (response.statusCode != 200) {
      throw XtreamException('http_${response.statusCode}');
    }

    try {
      final body = jsonDecode(response.body);
      if (body is List) return {'_list': body};
      return body as Map<String, dynamic>;
    } catch (_) {
      throw const XtreamException('invalid_response');
    }
  }

  // ---------------------------------------------------------------------------
  // Parsers
  // ---------------------------------------------------------------------------

  List<XtreamCategory> _parseCategories(Map<String, dynamic> data) {
    final list = (data['_list'] ?? data) as List;
    return list.map((item) {
      final m = item as Map<String, dynamic>;
      return XtreamCategory(
        id: '${m['category_id'] ?? ''}',
        name: '${m['category_name'] ?? 'Unknown'}',
      );
    }).toList();
  }

  List<Channel> _parseChannels(Map<String, dynamic> data) {
    final list = (data['_list'] ?? data) as List;
    return list.asMap().entries.map((entry) {
      final m = entry.value as Map<String, dynamic>;
      final streamId = '${m['stream_id'] ?? ''}';
      return Channel(
        id: '${sourceId}_ch_$streamId',
        sourceId: sourceId,
        name: '${m['name'] ?? 'Unknown'}',
        logoUrl: m['stream_icon'] as String?,
        streamUrl: buildStreamUrl(streamId, 'live'),
        groupTitle: m['category_name'] as String?,
        tvgId: m['epg_channel_id'] as String?,
        tvgName: m['name'] as String?,
        sortOrder: entry.key,
      );
    }).toList();
  }

  List<Movie> _parseMovies(Map<String, dynamic> data) {
    final list = (data['_list'] ?? data) as List;
    return list.map((item) {
      final m = item as Map<String, dynamic>;
      final streamId = '${m['stream_id'] ?? ''}';
      return Movie(
        id: '${sourceId}_mov_$streamId',
        sourceId: sourceId,
        title: '${m['name'] ?? 'Unknown'}',
        posterUrl: m['stream_icon'] as String?,
        streamUrl: buildStreamUrl(streamId, 'movie', ext: m['container_extension'] as String? ?? 'mp4'),
        genre: m['genre'] as String?,
        year: m['year'] as String?,
        rating: m['rating'] as String?,
        description: m['plot'] as String?,
      );
    }).toList();
  }

  List<Series> _parseSeries(Map<String, dynamic> data) {
    final list = (data['_list'] ?? data) as List;
    return list.map((item) {
      final m = item as Map<String, dynamic>;
      final seriesId = '${m['series_id'] ?? ''}';
      return Series(
        id: '${sourceId}_ser_$seriesId',
        sourceId: sourceId,
        title: '${m['name'] ?? 'Unknown'}',
        posterUrl: m['cover'] as String?,
        genre: m['genre'] as String?,
        year: m['releaseDate'] as String?,
        description: m['plot'] as String?,
      );
    }).toList();
  }

  List<Episode> _parseEpisodes(
    Map<String, dynamic> info,
    String localSeriesId,
  ) {
    final episodes = info['episodes'] as Map<String, dynamic>?;
    if (episodes == null) return [];

    final result = <Episode>[];
    for (final seasonKey in episodes.keys) {
      final seasonNum = int.tryParse(seasonKey) ?? 1;
      final eps = episodes[seasonKey] as List;
      for (final ep in eps) {
        final m = ep as Map<String, dynamic>;
        final episodeId = '${m['id'] ?? ''}';
        result.add(Episode(
          id: '${sourceId}_ep_$episodeId',
          seriesId: '${sourceId}_ser_$localSeriesId',
          sourceId: sourceId,
          season: seasonNum,
          episode: int.tryParse('${m['episode_num'] ?? 1}') ?? 1,
          title: '${m['title'] ?? 'Episode $episodeId'}',
          streamUrl: buildStreamUrl(
            episodeId,
            'series',
            ext: m['container_extension'] as String? ?? 'mp4',
          ),
          stillUrl: m['info'] != null
              ? (m['info'] as Map)['movie_image'] as String?
              : null,
        ));
      }
    }
    return result;
  }

  void dispose() => _http.close();
}
