import 'dart:isolate';

import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/episode.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/models/series.dart';

class M3uParseResult {
  const M3uParseResult({
    required this.channels,
    required this.movies,
    required this.series,
    required this.episodes,
    this.epgUrl,
  });

  final List<Channel> channels;
  final List<Movie> movies;
  final List<Series> series;
  final List<Episode> episodes;
  final String? epgUrl;
}

class M3uParser {
  /// Parses an M3U/M3U+ string in a separate isolate so the UI never blocks.
  static Future<M3uParseResult> parse(String content, String sourceId) {
    return Isolate.run(() => _parse(content, sourceId));
  }

  static M3uParseResult _parse(String content, String sourceId) {
    final lines = content.split('\n');

    String? epgUrl;
    final channels = <Channel>[];
    final movies = <Movie>[];
    final seriesMap = <String, Series>{};
    final episodes = <Episode>[];

    String? pendingExtinf;
    int sortIndex = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTM3U')) {
        epgUrl = _extractAttr(line, 'url-tvg') ??
            _extractAttr(line, 'x-tvg-url');
        continue;
      }

      if (line.startsWith('#EXTINF')) {
        pendingExtinf = line;
        continue;
      }

      if (line.startsWith('#')) continue;

      // This line is a stream URL — pair it with the previous #EXTINF.
      if (pendingExtinf == null) continue;

      final streamUrl = line;
      final attrs = _parseExtinf(pendingExtinf);
      pendingExtinf = null;

      final name = attrs['name'] ?? 'Unknown';
      final group = attrs['group-title'] ?? '';
      final id = _generateId(sourceId, streamUrl);

      if (_isVod(group, name)) {
        if (_isSeries(group, name)) {
          final seriesTitle = _extractSeriesTitle(name);
          final seriesId = _generateId(sourceId, seriesTitle);

          seriesMap.putIfAbsent(
            seriesId,
            () => Series(
              id: seriesId,
              sourceId: sourceId,
              title: seriesTitle,
              posterUrl: attrs['tvg-logo'],
              genre: group,
            ),
          );

          final nums = _parseEpisodeNumbers(name);
          episodes.add(Episode(
            id: id,
            seriesId: seriesId,
            sourceId: sourceId,
            season: nums.$1,
            episode: nums.$2,
            title: name,
            streamUrl: streamUrl,
          ));
        } else {
          movies.add(Movie(
            id: id,
            sourceId: sourceId,
            title: name,
            posterUrl: attrs['tvg-logo'],
            streamUrl: streamUrl,
            genre: group.isNotEmpty ? group : null,
          ));
        }
      } else {
        channels.add(Channel(
          id: id,
          sourceId: sourceId,
          name: name,
          logoUrl: attrs['tvg-logo'],
          streamUrl: streamUrl,
          groupTitle: group.isNotEmpty ? group : null,
          tvgId: attrs['tvg-id'],
          tvgName: attrs['tvg-name'],
          sortOrder: sortIndex++,
        ));
      }
    }

    return M3uParseResult(
      channels: channels,
      movies: movies,
      series: seriesMap.values.toList(),
      episodes: episodes,
      epgUrl: epgUrl,
    );
  }

  // ---------------------------------------------------------------------------
  // Attribute extraction
  // ---------------------------------------------------------------------------

  static String? _extractAttr(String line, String attr) {
    final pattern = RegExp('$attr="([^"]*)"', caseSensitive: false);
    return pattern.firstMatch(line)?.group(1);
  }

  /// Parses all key="value" attributes from an #EXTINF line plus the channel name.
  static Map<String, String> _parseExtinf(String line) {
    final result = <String, String>{};

    final attrPattern = RegExp(r'(\w[\w-]*)="([^"]*)"');
    for (final m in attrPattern.allMatches(line)) {
      result[m.group(1)!.toLowerCase()] = m.group(2)!;
    }

    // Channel name is everything after the final comma.
    final commaIdx = line.lastIndexOf(',');
    if (commaIdx != -1 && commaIdx < line.length - 1) {
      result['name'] = line.substring(commaIdx + 1).trim();
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Classification helpers
  // ---------------------------------------------------------------------------

  static const _vodKeywords = [
    'vod', 'movie', 'movies', 'film', 'films', 'series', 'shows',
  ];

  static bool _isVod(String group, String name) {
    final g = group.toLowerCase();
    return _vodKeywords.any((kw) => g.contains(kw));
  }

  static final _episodePattern = RegExp(r'[Ss](\d+)[Ee](\d+)');

  static bool _isSeries(String group, String name) {
    final g = group.toLowerCase();
    if (g.contains('series') || g.contains('shows')) return true;
    return _episodePattern.hasMatch(name);
  }

  static String _extractSeriesTitle(String episodeName) {
    final match = _episodePattern.firstMatch(episodeName);
    if (match == null) return episodeName;
    return episodeName.substring(0, match.start).trim().trimRight();
  }

  static (int, int) _parseEpisodeNumbers(String name) {
    final match = _episodePattern.firstMatch(name);
    if (match == null) return (1, 1);
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  static String _generateId(String sourceId, String key) {
    // Deterministic ID from source + key so re-parsing the same feed
    // produces the same IDs and upserts work correctly.
    return '${sourceId}_${key.hashCode.abs()}';
  }
}
