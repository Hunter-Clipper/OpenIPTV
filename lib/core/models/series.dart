class Series {
  const Series({
    required this.id,
    required this.sourceId,
    required this.title,
    this.posterUrl,
    this.genre,
    this.year,
    this.description,
  });

  final String id;
  final String sourceId;
  final String title;
  final String? posterUrl;
  final String? genre;
  final String? year;
  final String? description;

  Series copyWith({
    String? id,
    String? sourceId,
    String? title,
    String? posterUrl,
    String? genre,
    String? year,
    String? description,
  }) {
    return Series(
      id: id ?? this.id,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      description: description ?? this.description,
    );
  }
}
