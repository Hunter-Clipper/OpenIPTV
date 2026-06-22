class Movie {
  const Movie({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.streamUrl,
    this.posterUrl,
    this.genre,
    this.year,
    this.rating,
    this.description,
    this.watchedDuration,
    this.totalDuration,
  });

  final String id;
  final String sourceId;
  final String title;
  final String? posterUrl;
  final String streamUrl;
  final String? genre;
  final String? year;
  final String? rating;
  final String? description;
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

  Movie copyWith({
    String? id,
    String? sourceId,
    String? title,
    String? posterUrl,
    String? streamUrl,
    String? genre,
    String? year,
    String? rating,
    String? description,
    Duration? watchedDuration,
    Duration? totalDuration,
  }) {
    return Movie(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      rating: rating ?? this.rating,
      description: description ?? this.description,
      watchedDuration: watchedDuration ?? this.watchedDuration,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }
}
