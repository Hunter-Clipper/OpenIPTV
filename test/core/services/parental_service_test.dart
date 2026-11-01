import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  group('isLockedContent', () {
    Future<AppPreferences> prefs({bool on = true}) async {
      SharedPreferences.setMockInitialValues({});
      final p = AppPreferences(await SharedPreferences.getInstance());
      await p.setParentalProtectionEnabled(on);
      await p.setParentalLockedCategories(['Sports']);
      return p;
    }

    test('manually locked and adult categories are locked', () async {
      final p = await prefs();
      expect(isLockedContent(['News', 'Sports'], p), isTrue);
      expect(isLockedContent(['XXX - Movies'], p), isTrue);
      expect(isLockedContent(['News'], p), isFalse);
    });

    test('stays locked even when unlocked for the session', () async {
      final p = await prefs();
      expect(isCategoryLocked('Sports', p, {'Sports'}), isFalse);
      expect(isLockedContent(['Sports'], p), isTrue);
    });

    test('nothing is locked with parental protection off', () async {
      final p = await prefs(on: false);
      expect(isLockedContent(['Sports', 'XXX'], p), isFalse);
    });
  });
}
