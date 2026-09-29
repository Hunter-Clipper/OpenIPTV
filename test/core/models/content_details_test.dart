import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/content_details.dart';

void main() {
  test('parses a typical get_vod_info response', () {
    final d = ContentDetails.fromXtream({
      'info': {
        'backdrop_path': ['https://img.example/backdrop.jpg'],
        'plot': ' A story. ',
        'cast': 'A, B',
        'director': 'C',
        'duration_secs': 6720,
        'rating': '7.25',
        'releasedate': '2021-05-01',
      },
    });
    expect(d.backdropUrl, 'https://img.example/backdrop.jpg');
    expect(d.plot, 'A story.');
    expect(d.cast, 'A, B');
    expect(d.director, 'C');
    expect(d.runtime, const Duration(minutes: 112));
    expect(d.rating, '7.3');
    expect(d.releaseDate, '2021-05-01');
  });

  test('tolerates missing, empty and oddly typed fields', () {
    final d = ContentDetails.fromXtream({
      'info': {
        'backdrop_path': '',
        'plot': '',
        'duration': '00:45:00',
        'rating': '0',
        'cast': null,
      },
    });
    expect(d.backdropUrl, isNull);
    expect(d.plot, isNull);
    expect(d.runtime, const Duration(minutes: 45));
    expect(d.rating, isNull);
    expect(d.cast, isNull);

    expect(ContentDetails.fromXtream({'info': []}).plot, isNull);
    expect(ContentDetails.fromXtream({}).episodes, isEmpty);
  });

  test('parses per-episode details of get_series_info', () {
    final d = ContentDetails.fromXtream({
      'info': {'backdrop_path': 'https://img.example/b.jpg',
          'episode_run_time': '42'},
      'episodes': {
        '1': [
          {
            'id': '1001',
            'info': {
              'movie_image': 'https://img.example/s1e1.jpg',
              'plot': 'Pilot.',
              'duration_secs': '2520',
            },
          },
          {'id': '1002', 'info': []},
        ],
      },
    });
    expect(d.backdropUrl, 'https://img.example/b.jpg');
    expect(d.runtime, const Duration(minutes: 42));
    expect(d.episodes['1001']!.stillUrl, 'https://img.example/s1e1.jpg');
    expect(d.episodes['1001']!.plot, 'Pilot.');
    expect(d.episodes['1001']!.runtime, const Duration(minutes: 42));
    expect(d.episodes['1002']!.stillUrl, isNull);
  });
}
