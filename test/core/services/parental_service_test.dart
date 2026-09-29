import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/parental_service.dart';

void main() {
  group('isAdultCategory', () {
    test('detects adult categories', () {
      expect(isAdultCategory('XXX - Movies'), isTrue);
      expect(isAdultCategory('Adult 18+'), isTrue);
      expect(isAdultCategory('ADULT CHANNELS'), isTrue);
    });

    test('does not flag known non-adult names', () {
      // Adult Swim is a cartoon network; the rest are ordinary genres.
      expect(isAdultCategory('DrewLive Adult Swim 24/7'), isFalse);
      expect(isAdultCategory('Young Adult Movies'), isFalse);
      expect(isAdultCategory('Adult Contemporary Radio'), isFalse);
    });

    test('still flags adult content that mentions a safe phrase', () {
      expect(isAdultCategory('Adult Swim + XXX'), isTrue);
    });
  });
}
