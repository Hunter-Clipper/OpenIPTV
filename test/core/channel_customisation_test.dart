import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/channel_customisation.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('saved channel tweaks', () {
    test('round-trip, per profile', () {
      final json = encodeChannelCustom({
        'p1': const ChannelCustom(hidden: {'c2', 'c1'}, names: {'c3': 'News'}),
        'p2': const ChannelCustom(),
      });
      final back = parseChannelCustom(json);
      expect(back.keys, ['p1']); // an empty profile is not stored
      expect(back['p1']!.hidden, {'c1', 'c2'});
      expect(back['p1']!.names, {'c3': 'News'});
    });

    test('bad or missing data reads as nothing', () {
      expect(parseChannelCustom(null), isEmpty);
      expect(parseChannelCustom(''), isEmpty);
      expect(parseChannelCustom('not json'), isEmpty);
      expect(parseChannelCustom('[1,2]'), isEmpty);
      final odd = parseChannelCustom(
          '{"p":{"hidden":[1,"a"],"names":{"x":"  ","y":"Y","z":5}}}');
      expect(odd['p']!.hidden, {'a'});
      expect(odd['p']!.names, {'y': 'Y'});
    });
  });

  group('ChannelCustomNotifier', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = AppPreferences(await SharedPreferences.getInstance());
      container = ProviderContainer(overrides: [
        appPreferencesProvider.overrideWith((ref) async => prefs),
        activeProfileIdProvider.overrideWithValue('p1'),
      ]);
      await container.read(appPreferencesProvider.future);
    });
    tearDown(() => container.dispose());

    test('hide, unhide, rename and reset are saved', () async {
      final n = container.read(channelCustomProvider.notifier);
      await n.hide('a');
      await n.hide('b');
      await n.rename('a', '  My Channel ');
      expect(container.read(channelCustomProvider).hidden, {'a', 'b'});
      expect(container.read(channelCustomProvider).names, {'a': 'My Channel'});

      await n.unhide('a');
      await n.rename('a', '');
      var state = container.read(channelCustomProvider);
      expect(state.hidden, {'b'});
      expect(state.names, isEmpty);

      // Saved: a fresh read of the preferences sees it.
      final prefs = await container.read(appPreferencesProvider.future);
      expect(parseChannelCustom(prefs.channelCustomJson)['p1']!.hidden, {'b'});

      await n.unhideAll();
      state = container.read(channelCustomProvider);
      expect(state.hidden, isEmpty);
    });
  });
}
