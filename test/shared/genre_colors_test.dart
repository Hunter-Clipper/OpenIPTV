import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/shared/utils/genre_colors.dart';

void main() {
  test('matches whole words in the programme category', () {
    expect(genreBucket('Sports / Football'), GenreBucket.sports);
    expect(genreBucket('Feature Film'), GenreBucket.movies);
    expect(genreBucket("Children's"), GenreBucket.kids);
    expect(genreBucket('Weather'), GenreBucket.news);
  });

  test('kids wins when a category names several', () {
    expect(genreBucket('Kids Movies'), GenreBucket.kids);
  });

  test('substrings of other words do not match', () {
    expect(genreBucket('Gamespot Reviews'), GenreBucket.other);
    expect(genreBucket('Moviestar Radio'), GenreBucket.other);
  });

  test('falls back to the channel categories, then to other', () {
    expect(genreBucket(null, ['UK', 'Sports HD']), GenreBucket.sports);
    expect(genreBucket('', ['Entertainment (UK)']), GenreBucket.other);
    expect(genreBucket(null), GenreBucket.other);
  });
}
