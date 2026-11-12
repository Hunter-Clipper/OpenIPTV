import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/epg/guide_matcher.dart';

GuideChannel g(String guide, String id, [String? name]) => GuideChannel(
    guideId: guide, xmltvId: id, name: name ?? nameFromGuideId(id));

void main() {
  group('normaliseChannelName', () {
    test('drops quality words and regions in brackets, prefixes and ends', () {
      for (final n in [
        'BBC One HD',
        'BBC 1 (UK)',
        'UK: BBC One',
        '|UK| BBC ONE FHD',
        'UK - BBC One',
        'BBC One UK',
      ]) {
        final x = normaliseChannelName(n);
        expect(x.tokens, {'bbc', '1'}, reason: n);
      }
      expect(normaliseChannelName('BBC 1 (UK)').region, 'uk');
      expect(normaliseChannelName('CNN US').region, 'us');
      expect(normaliseChannelName('FX HD us2').region, 'us');
    });

    test('numbers are kept apart and ITV1 equals ITV 1', () {
      expect(normaliseChannelName('ITV1 HD').tokens, {'itv', '1'});
      expect(normaliseChannelName('ITV 1').tokens, {'itv', '1'});
      expect(normaliseChannelName('E4 +1').tokens, {'e', '4', 'plus1'});
      expect(normaliseChannelName('AMC+').tokens, {'amc', 'plus'});
    });

    test('guide names without a display name come from the id', () {
      expect(nameFromGuideId('BBC.One.HD.uk'), 'BBC One HD uk');
    });
  });

  group('GuideMatcher', () {
    final matcher = GuideMatcher([
      g('a', 'BBCOne.uk', 'UK - BBC One'),
      g('a', 'BBCTwo.uk', 'UK - BBC Two'),
      g('a', 'E4.uk', 'E4'),
      g('a', 'E4+1.uk', 'E4 +1'),
      g('a', 'CNN.uk', 'CNN'),
      g('b', 'BBC.Two.HD.uk'),
      g('b', 'CNN.HD.us2'),
      g('b', 'FX.HD.us2'),
      g('b', 'FX.HD.(Pacific).us2'),
      g('b', 'AMC+.us2'),
      g('b', 'Discovery.HD.uk'),
      g('b', 'Discovery.Channel.HD.us2'),
    ]);

    test('matches a name however the provider decorates it', () {
      expect(matcher.match('BBC 1 (UK)')?.channel.xmltvId, 'BBCOne.uk');
      expect(matcher.match('|UK| BBC ONE HD')?.channel.xmltvId, 'BBCOne.uk');
    });

    test('BBC 1 never matches BBC 2, and +1 never matches the parent', () {
      expect(matcher.match('BBC 3 (UK)'), isNull);
      expect(matcher.match('E4 +1')?.channel.xmltvId, 'E4+1.uk');
      expect(matcher.match('E4 HD')?.channel.xmltvId, 'E4.uk');
    });

    test('the region of the name and of the guide id must agree', () {
      expect(matcher.match('CNN US')?.channel.xmltvId, 'CNN.HD.us2');
      expect(matcher.match('CNN (UK)')?.channel.xmltvId, 'CNN.uk');
      expect(matcher.match('Discovery Channel (USA)')?.channel.xmltvId,
          'Discovery.Channel.HD.us2');
    });

    test('the same station in two guides goes to the guide listed first', () {
      expect(matcher.match('BBC 2 (UK)')?.channel.guideId, 'a');
    });

    test('the plain feed wins over its regional variant', () {
      expect(matcher.match('FX (USA)')?.channel.xmltvId, 'FX.HD.us2');
    });

    test('AMC is not AMC Plus', () {
      expect(matcher.match('AMC (USA)'), isNull);
      expect(matcher.match('AMC Plus (USA)')?.channel.xmltvId, 'AMC+.us2');
    });

    test('a guide id the playlist already carries wins', () {
      final m = matcher.match('Something else', tvgId: 'bbcone.UK');
      expect(m?.channel.xmltvId, 'BBCOne.uk');
      expect(m?.byId, isTrue);
    });

    test('unknown channels and two equally good regional guides stay empty',
        () {
      expect(matcher.match('Completely Unknown Channel'), isNull);
      final twin = GuideMatcher([
        g('a', 'BBC.One.London.uk', 'BBC One London'),
        g('a', 'BBC.One.Wales.uk', 'BBC One Wales'),
      ]);
      expect(twin.match('BBC One'), isNull);
    });

    test('search finds guide channels containing every word', () {
      final found = matcher.search('bbc two');
      expect(found.map((c) => c.xmltvId), contains('BBCTwo.uk'));
      expect(matcher.search(''), isEmpty);
    });
  });
}
