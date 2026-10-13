import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/channel.dart';
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
}
