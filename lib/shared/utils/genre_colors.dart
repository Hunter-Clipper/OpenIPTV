/// The few colour families a programme can fall into, so a guide can tint
/// its cells by kind of show (the Retro Cable look, #178). Matched by whole
/// words in the programme's category (and, failing that, its channel's
/// categories), like the genre icons: providers name them all sorts of ways.
enum GenreBucket { sports, movies, kids, news, other }

const _sports = {
  'sport', 'sports', 'football', 'soccer', 'basketball', 'baseball',
  'hockey', 'nfl', 'nba', 'mlb', 'nhl', 'tennis', 'golf', 'racing', 'boxing',
  'ufc', 'wrestling', 'cricket', 'rugby', 'olympics', 'f1', 'motorsport',
  'fight', 'league',
};
const _movies = {
  'movie', 'movies', 'film', 'films', 'cinema', 'drama', 'thriller', 'horror',
  'romance', 'western', 'feature',
};
const _kids = {
  'kids', 'kid', 'children', 'childrens', 'child', 'family', 'cartoon',
  'cartoons', 'animation', 'animated', 'toddler', 'preschool', 'junior',
};
const _news = {
  'news', 'weather', 'politics', 'business', 'finance', 'current', 'affairs',
  'headlines',
};

/// Words of [text], lower-cased, split on anything that isn't a letter or
/// a digit ("Sports/Football" gives sports, football).
Iterable<String> _words(String text) => text
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((w) => w.isNotEmpty);

GenreBucket? _bucketOf(String? text) {
  if (text == null || text.trim().isEmpty) return null;
  final words = _words(text).toSet();
  // Order matters when a category names several ("Kids Movies" is kids).
  if (words.any(_kids.contains)) return GenreBucket.kids;
  if (words.any(_sports.contains)) return GenreBucket.sports;
  if (words.any(_movies.contains)) return GenreBucket.movies;
  if (words.any(_news.contains)) return GenreBucket.news;
  return null;
}

/// The bucket for a programme: its own [category] first, then the
/// [fallback] texts (the channel's categories), else [GenreBucket.other].
GenreBucket genreBucket(String? category, [Iterable<String> fallback = const []]) {
  final own = _bucketOf(category);
  if (own != null) return own;
  for (final f in fallback) {
    final b = _bucketOf(f);
    if (b != null) return b;
  }
  return GenreBucket.other;
}
