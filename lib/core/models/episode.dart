class Episode {
  const Episode({
    required this.id,
    required this.seriesId,
    required this.sourceId,
    required this.season,
    required this.episode,
    required this.title,
    required this.streamUrl,
    this.stillUrl,
    this.watchedDuration,
    this.totalDuration,
  });

  final String id;
  final String seriesId;
  final String sourceId;
  final int season;
  final int episode;
  final String title;
  final String streamUrl;
  final String? stillUrl;
  final Duration? watchedDuration;
  final Duration? totalDuration;

  bool get isWatched {
    if (watchedDuration == null || totalDuration == null) return false;
    if (totalDuration!.inSeconds == 0) return false;
    return watchedDuration!.inSeconds / totalDuration!.inSeconds >= 0.9;
  }

  bool get isInProgress {
    if (watchedDuration == null || watchedDuration!.inSeconds == 0) return false;
    return !isWatched;
  }

  double get watchProgress {
    if (watchedDuration == null || totalDuration == null) return 0;
    if (totalDuration!.inSeconds == 0) return 0;
    return (watchedDuration!.inSeconds / totalDuration!.inSeconds).clamp(0.0, 1.0);
  }

  String get episodeLabel => 'S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}';

  Episode copyWith({
    String? id,
    String? seriesId,
    String? sourceId,
    int? season,
    int? episode,
    String? title,
    String? streamUrl,
    String? stillUrl,
    Duration? watchedDuration,
    Duration? totalDuration,
  }) {
    return Episode(
      id: id ?? this.id,
      seriesId: seriesId ?? this.seriesId,
      sourceId: sourceId ?? this.sourceId,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      title: title ?? this.title,
      streamUrl: streamUrl ?? this.streamUrl,
      stillUrl: stillUrl ?? this.stillUrl,
      watchedDuration: watchedDuration ?? this.watchedDuration,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }
}
