import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/epg/guide_matcher.dart';
import 'package:open_iptv/core/epg/local_stations.dart';

GuideChannel g(String guide, String id, [String? name]) => GuideChannel(
    guideId: guide, xmltvId: id, name: name ?? nameFromGuideId(id));

void main() {
  final matcher = GuideMatcher([
    // epgshare01-style locals feed: call signs, sub-channels, translators.
    g('loc', 'WNBC-DT.us_locals1', 'WNBC-DT'),
    g('loc', 'WABC-DT.us_locals1', 'WABC-DT'),
    g('loc', 'WABC-DT2.us_locals1', 'WABC-DT2'),
    g('loc', 'WCBS-DT.us_locals1', 'WCBS-DT'),
    g('loc', 'WNYW-DT.us_locals1', 'WNYW-DT'),
    g('loc', 'WPVI-DT.us_locals1', 'WPVI-DT'),
    g('loc', 'WLS-DT.us_locals1', 'WLS-DT'),
    g('loc', 'WGN-DT.us_locals1', 'WGN-DT'),
    g('loc', 'KXII-DT.us_locals1', 'KXII-DT'),
    g('loc', 'KXII-DT3.us_locals1', 'KXII-DT3'),
    g('loc', 'KING-DT.us_locals1', 'KING-DT'),
    g('loc', 'WXYZ-DT.us_locals1', 'WXYZ-DT'),
    g('loc', 'K44JF-D.us_locals1', 'K44JF-D'),
    g('loc', 'KYLE-DT.us_locals1', 'KYLE-DT'),
    g('loc', 'KIDZ-LD.us_locals1', 'KIDZ-LD'),
    g('loc', 'WSOC-DT.us_locals1', 'WSOC-DT'),
    g('loc', 'WKAQ-DT.us_locals1', 'WKAQ-DT'),
    g('loc', 'KNSD-DT.us_locals1', 'KNSD-DT'),
    g('loc', 'WCVB-DT.us_locals1', 'WCVB-DT'),
    // a national guide listing the networks too
    g('us', 'NBC.HD.us2'),
    g('us', 'FOX.News.Channel.HD.us2'),
    g('us', 'CBS.Sports.Network.HD.us2'),
  ]);

  String? id(String name) => matcher.match(name)?.channel.xmltvId;

  group('call signs', () {
    test('found in the name however it is written', () {
      expect(id('NBC 4 NEW YORK (WNBC) HD'), 'WNBC-DT.us_locals1');
      expect(id('US| ABC (WPVI) PHILADELPHIA'), 'WPVI-DT.us_locals1');
      expect(id('wnbc'), 'WNBC-DT.us_locals1');
      expect(id('ABC 7 WLS-TV Chicago'), 'WLS-DT.us_locals1');
      expect(id('KING 5 Seattle'), 'KING-DT.us_locals1');
    });

    test('the main broadcast is used, never a sub-channel', () {
      expect(id('ABC (WABC) New York'), 'WABC-DT.us_locals1');
      expect(id('KXII'), 'KXII-DT.us_locals1');
    });

    test('a call sign the guide does not have gives no match', () {
      expect(id('NBC (KXAS) Dallas'), isNull);
    });

    test('two call signs in one name are not guessed', () {
      expect(id('ABC WABC / NBC WNBC'), isNull);
    });

    test('a different channel that merely contains a call sign', () {
      expect(id('WGN America'), isNull);
      expect(id('WGN Chicago'), 'WGN-DT.us_locals1');
    });
  });

  group('things that only look like a local station', () {
    test('an ordinary channel whose name contains a call sign', () {
      expect(id('South Park: Kyle Collection (United States)'), isNull);
      expect(id('WOW Kidz (720p)'), isNull);
      expect(id('King TV (720p) [Not 24/7]'), isNull);
      expect(id('WSOC Now (1080p) [Geo-blocked]'), isNull);
    });

    test('sub-channels are never linked to the main station', () {
      expect(id('Telemundo KNSD (1080p)'), isNull);
      expect(id('True Crime Network WCVB-TV (720p)'), isNull);
      expect(id('WKAQ-TV 2.2 (1080p)'), isNull);
    });

    test('the same station written plainly still resolves', () {
      expect(id('WPVI 6.1 (720p)'), 'WPVI-DT.us_locals1');
      expect(id('NBC WNBC (1080p) [Geo-blocked]'), 'WNBC-DT.us_locals1');
      expect(id('KING-TV'), 'KING-DT.us_locals1');
      expect(id('NBC KNSD (720p)'), 'KNSD-DT.us_locals1');
    });
  });

  group('network and city', () {
    test('big-market affiliates resolve through the market table', () {
      expect(id('FOX 5 NY'), 'WNYW-DT.us_locals1');
      expect(id('ABC 7 CHICAGO'), 'WLS-DT.us_locals1');
      expect(id('CBS 2 New York HD'), 'WCBS-DT.us_locals1');
      expect(id('US: NBC NEW YORK'), 'WNBC-DT.us_locals1');
    });

    test('a station missing from the guide is not replaced by the network',
        () {
      // Dallas NBC is KXAS, which this guide lacks: no link, and certainly
      // not the national NBC guide.
      expect(id('NBC 5 DALLAS'), isNull);
    });

    test('a network in a city we do not know is left alone', () {
      expect(id('ABC 7 Nowhereville'), isNull);
    });

    test('cable cousins of a network are not locals', () {
      expect(id('FOX News Channel'), 'FOX.News.Channel.HD.us2');
      expect(id('CBS Sports Network'), 'CBS.Sports.Network.HD.us2');
    });

    test('a national network name alone uses ordinary matching', () {
      expect(id('NBC (USA)'), 'NBC.HD.us2');
    });
  });

  group('market table', () {
    test('every entry is a plain call sign and no station is listed twice',
        () {
      final seen = <String>{};
      for (final market in kMarketStations.values) {
        for (final sign in market.values) {
          expect(RegExp(r'^[KW][A-Z]{2,3}$').hasMatch(sign), isTrue,
              reason: sign);
          expect(seen.add(sign), isTrue, reason: '$sign listed twice');
        }
      }
    });

    test('every alias points at a market with stations', () {
      for (final market in kMarketAliases.values) {
        expect(kMarketStations.containsKey(market), isTrue, reason: market);
      }
    });

    test('affiliations that changed are not guessed', () {
      final atlanta = GuideMatcher([g('loc', 'WANF-DT.us_locals1', 'WANF-DT')]);
      expect(atlanta.match('CBS 46 Atlanta'), isNull);
    });
  });
}
