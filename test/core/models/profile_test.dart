import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/profile.dart';

Profile _profile({
  String? pinHash,
  List<String>? favoriteChannelIds,
}) =>
    Profile(
      id: 'test-id',
      name: 'Test',
      avatarEmoji: '🧑',
      pinHash: pinHash,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      favoriteChannelIds: favoriteChannelIds ?? [],
    );

void main() {
  group('Profile', () {
    test('hasPin is false when pinHash is null', () {
      expect(_profile().hasPin, isFalse);
    });

    test('hasPin is true when pinHash is set', () {
      expect(_profile(pinHash: 'abc123').hasPin, isTrue);
    });

    test('copyWith preserves unspecified fields', () {
      final p = _profile(pinHash: 'abc');
      final copy = p.copyWith(name: 'New Name');
      expect(copy.name, 'New Name');
      expect(copy.pinHash, 'abc');
      expect(copy.id, p.id);
    });

    test('copyWith clearPin removes pinHash', () {
      final p = _profile(pinHash: 'abc');
      final copy = p.copyWith(clearPin: true);
      expect(copy.pinHash, isNull);
      expect(copy.hasPin, isFalse);
    });

    test('avatarOptions contains exactly 20 entries', () {
      expect(Profile.avatarOptions.length, 20);
    });

    test('default values are applied correctly', () {
      final p = _profile();
      expect(p.defaultCategory, 'All');
      expect(p.channelSortOrder, 'provider');
      expect(p.sourceIds, isEmpty);
      expect(p.favoriteChannelIds, isEmpty);
      expect(p.hiddenCategories, isEmpty);
    });

    test('favoriteChannelIds are independent between copies', () {
      final p = _profile(favoriteChannelIds: ['ch1', 'ch2']);
      final copy = p.copyWith(
        favoriteChannelIds: List.from(p.favoriteChannelIds)..add('ch3'),
      );
      expect(p.favoriteChannelIds.length, 2);
      expect(copy.favoriteChannelIds.length, 3);
    });
  });
}
