import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/channel.dart';

Channel _ch(String? group) => Channel(
      id: 'c',
      sourceId: 's',
      name: 'C',
      streamUrl: 'http://c',
      sortOrder: 0,
      groupTitle: group,
    );

void main() {
  group('Channel.categories', () {
    test('splits semicolon-separated group titles', () {
      expect(_ch('Culture;Entertainment; News').categories,
          ['Culture', 'Entertainment', 'News']);
    });

    test('keeps a plain group title whole', () {
      expect(_ch('US| NEWS NETWORK').categories, ['US| NEWS NETWORK']);
    });

    test('falls back to Uncategorized for missing or blank groups', () {
      expect(_ch(null).categories, ['Uncategorized']);
      expect(_ch(' ; ').categories, ['Uncategorized']);
    });
  });
}
