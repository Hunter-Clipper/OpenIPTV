import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/services/category_order.dart';
import 'package:open_iptv/features/live_tv/live_categories.dart';

void main() {
  var n = 0;
  Channel ch(String group) => Channel(
        id: 'c${n++}',
        sourceId: 's',
        name: 'Channel $n',
        streamUrl: 'http://example.test/$n.ts',
        sortOrder: n,
        groupTitle: group,
      );

  final channels = [
    ch('Sports'),
    ch('News;Kids'),
    ch('Adult XXX'),
    ch('Sports'),
    ch('Documentary'),
  ];

  test('first-appearance order, each category once', () {
    expect(liveCategories(channels),
        ['Sports', 'News', 'Kids', 'Adult XXX', 'Documentary']);
  });

  test('A–Z', () {
    expect(liveCategories(channels, az: true),
        ['Adult XXX', 'Documentary', 'Kids', 'News', 'Sports']);
  });

  test('hidden, adult on a kids profile, and skipped are left out', () {
    expect(
      liveCategories(channels,
          hidden: {'News'}, isKid: true, skip: (c) => c == 'Documentary'),
      ['Sports', 'Kids'],
    );
  });

  test("a profile's own order comes first; new categories follow", () {
    expect(
      liveCategories(channels, order: ['Documentary', 'Gone', 'Sports']),
      ['Documentary', 'Sports', 'News', 'Kids', 'Adult XXX'],
    );
  });

  test('a custom order beats A–Z', () {
    expect(
      liveCategories(channels, az: true, order: ['Sports', 'News']),
      ['Sports', 'News', 'Adult XXX', 'Documentary', 'Kids'],
    );
  });

  group('reorderedCategories', () {
    final visible = ['A', 'B', 'C'];

    test('moves a category up or down', () {
      expect(reorderedCategories(visible, 'B', -1, []), ['B', 'A', 'C']);
      expect(reorderedCategories(visible, 'B', 1, []), ['A', 'C', 'B']);
    });

    test('cannot move past either end', () {
      expect(reorderedCategories(visible, 'A', -1, ['x']), ['x']);
      expect(reorderedCategories(visible, 'C', 1, ['x']), ['x']);
      expect(reorderedCategories(visible, 'Z', 1, ['x']), ['x']);
    });

    test('hidden categories keep their saved place after the visible ones',
        () {
      expect(reorderedCategories(visible, 'C', -1, ['H', 'A', 'B', 'C']),
          ['A', 'C', 'B', 'H']);
    });
  });
}
