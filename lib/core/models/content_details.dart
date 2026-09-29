/// Extra artwork and metadata for a movie or series detail page, fetched on
/// demand from the provider (Xtream `get_vod_info` / `get_series_info`).
/// Not stored in the catalog: the sync lists don't carry it, and fetching it
/// for tens of thousands of titles up front would be far too slow.
class ContentDetails {
  const ContentDetails({
    this.backdropUrl,
    this.plot,
    this.cast,
    this.director,
    this.genres,
    this.runtime,
    this.rating,
    this.releaseDate,
    this.episodes = const {},
  });

  /// Parses the `info` block of a `get_vod_info` / `get_series_info`
  /// response. Providers differ wildly: fields may be missing, empty, a
  /// string where a list is expected, or a number as a string.
  factory ContentDetails.fromXtream(Map<String, dynamic> response) {
    final info = response['info'];
    final m = info is Map ? info.cast<String, dynamic>() : <String, dynamic>{};
    return ContentDetails(
      backdropUrl: _firstUrl(m['backdrop_path']),
      plot: _text(m['plot']) ?? _text(m['description']),
      cast: _text(m['cast']) ?? _text(m['actors']),
      director: _text(m['director']),
      genres: _text(m['genre']),
      runtime: _duration(m['duration_secs'], m['duration']) ??
          _minutes(m['episode_run_time']),
      rating: _rating(m['rating']),
      releaseDate: _text(m['releasedate']) ?? _text(m['releaseDate']),
      episodes: _episodes(response['episodes']),
    );
  }

  final String? backdropUrl;
  final String? plot;
  final String? cast;
  final String? director;
  final String? genres;
  final Duration? runtime;
  final String? rating;
  final String? releaseDate;

  /// Per-episode details, keyed by the provider's episode id.
  final Map<String, EpisodeDetails> episodes;

  static const empty = ContentDetails();

  static Map<String, EpisodeDetails> _episodes(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, EpisodeDetails>{};
    for (final season in raw.values) {
      if (season is! List) continue;
      for (final ep in season) {
        if (ep is! Map) continue;
        final info = ep['info'];
        final m = info is Map ? info : const {};
        out['${ep['id']}'] = EpisodeDetails(
          stillUrl: _firstUrl(m['movie_image']),
          plot: _text(m['plot']),
          runtime: _duration(m['duration_secs'], m['duration']),
        );
      }
    }
    return out;
  }
}

class EpisodeDetails {
  const EpisodeDetails({this.stillUrl, this.plot, this.runtime});

  final String? stillUrl;
  final String? plot;
  final Duration? runtime;
}

String? _text(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty || s == 'null' || s == 'N/A' ? null : s;
}

String? _firstUrl(Object? v) {
  final first = v is List ? (v.isEmpty ? null : v.first) : v;
  final s = _text(first);
  return s != null && s.startsWith('http') ? s : null;
}

Duration? _duration(Object? secs, Object? hms) {
  final s = int.tryParse(_text(secs) ?? '');
  if (s != null && s > 0) return Duration(seconds: s);
  // "01:52:10"
  final parts = (_text(hms) ?? '').split(':').map(int.tryParse).toList();
  if (parts.length == 3 && !parts.contains(null)) {
    final d =
        Duration(hours: parts[0]!, minutes: parts[1]!, seconds: parts[2]!);
    return d > Duration.zero ? d : null;
  }
  return null;
}

Duration? _minutes(Object? v) {
  final m = int.tryParse(_text(v) ?? '');
  return m != null && m > 0 ? Duration(minutes: m) : null;
}

String? _rating(Object? v) {
  final r = double.tryParse(_text(v) ?? '');
  return r == null || r <= 0 ? null : r.toStringAsFixed(1);
}
