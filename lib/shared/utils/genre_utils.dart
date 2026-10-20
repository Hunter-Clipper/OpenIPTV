import 'package:open_iptv/core/services/parental_service.dart';

/// Filters items by genre, using exact match on split genre names.
///
/// A substring match would put "XXX - Movies" titles under "Movies",
/// slipping adult titles past the category's parental lock.
List<T> filterByGenre<T>(
  List<T> items,
  String genre,
  String? Function(T) genreOf,
) {
  if (genre == 'All') return List.of(items);
  final lowerGenre = genre.toLowerCase();
  return items
      .where(
        (item) =>
            splitGenres(genreOf(item)).any((g) => g.toLowerCase() == lowerGenre),
      )
      .toList();
}

/// Builds a sorted list of genre names from items, excluding hidden genres.
List<String> buildGenreNames<T>(
  List<T> items,
  Set<String> hidden,
  String sort,
  String? Function(T) genreOf,
) {
  final seen = <String>{};
  final genres = <String>[];
  for (final item in items) {
    for (final g in splitGenres(genreOf(item))) {
      if (g.isNotEmpty && !hidden.contains(g) && seen.add(g)) genres.add(g);
    }
  }
  if (sort == 'az') genres.sort();
  return genres;
}

/// Builds a map of genre name to item count.
Map<String, int> buildGenreCounts<T>(
  List<T> items,
  String? Function(T) genreOf,
) {
  final counts = <String, int>{};
  for (final item in items) {
    for (final g in splitGenres(genreOf(item))) {
      if (g.isEmpty) continue;
      counts[g] = (counts[g] ?? 0) + 1;
    }
  }
  return counts;
}
