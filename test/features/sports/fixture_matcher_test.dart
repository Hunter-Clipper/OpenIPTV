import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/features/sports/fixture_matcher.dart';

Channel ch(String id, String name, {bool fav = false, bool catchup = false}) =>
    Channel(
      id: id,
      sourceId: 's',
      name: name,
      streamUrl: 'http://x/$id',
      sortOrder: 0,
      isFavorite: fav,
      hasCatchup: catchup,
    );

Programme prog(String ch, DateTime start, String title, {int mins = 120}) =>
    Programme(
      channelId: ch,
      start: start,
      end: start.add(Duration(minutes: mins)),
      title: title,
    );

void main() {
  final kickoff = DateTime.utc(2026, 11, 19, 20, 0);
  final now = DateTime.utc(2026, 11, 19, 19, 30);
  final fixture = Fixture(
      id: '1',
      home: 'Manchester United',
      away: 'Arsenal FC',
      kickoff: kickoff,
      league: 'Premier League');

  // American-style team: city + nickname, as the fixtures source gives it.
  final colts = Fixture(
    id: 'nfl:1',
    home: 'Houston Texans',
    away: 'Indianapolis Colts',
    homeNames: const ['Texans'],
    awayNames: const ['Colts'],
    homePlace: 'Houston',
    awayPlace: 'Indianapolis',
    kickoff: DateTime.utc(2026, 11, 20, 1, 15),
  );
  final nflNow = DateTime.utc(2026, 11, 19, 22, 0);

  List<String> names(Fixture f, List<String> channelNames, {DateTime? at}) {
    final channels = [
      for (var i = 0; i < channelNames.length; i++) ch('c$i', channelNames[i])
    ];
    return const FixtureMatcher()
        .match(f,
            channels: channels, programmes: const [], now: at ?? nflNow)
        .map((m) => m.channel.name)
        .toList();
  }

  group('normalizeTeam / mentionsTeam', () {
    test('folds accents, punctuation and noise words', () {
      expect(normalizeTeam('Mörrums GoIS IK'), 'morrums gois ik');
      expect(normalizeTeam('Arsenal FC'), 'arsenal');
      expect(normalizeTeam('Man Utd'), 'manchester united');
    });

    test('matches whole words only', () {
      expect(mentionsTeam('Inter', 'Intermezzo news'), isFalse);
      expect(mentionsTeam('Arsenal', 'Arsenal v Chelsea - League'), isTrue);
    });

    test('uses aliases both ways', () {
      expect(mentionsTeam('Manchester United', 'Man Utd v Arsenal'), isTrue);
      expect(mentionsTeam('Man Utd', 'Manchester United v Arsenal'), isTrue);
    });
  });

  group('extractNameDates', () {
    test('reads ISO, month-day and slash dates', () {
      expect(
          extractNameDates('X (2026-11-19 18:30:05)', now: now),
          [DateTime.utc(2026, 11, 19)]);
      expect(extractNameDates('Team A vs Team B Nov 19 6:30PM ET', now: now),
          [DateTime.utc(2026, 11, 19)]);
      expect(extractNameDates('Game 11/20 8pm', now: now),
          [DateTime.utc(2026, 11, 20)]);
    });

    test('a time alone is not a date; odd numbers are ignored', () {
      expect(extractNameDates('NFL : 01 - TNF 8:15pm Colts at Texans', now: now),
          isEmpty);
      expect(extractNameDates('[24/7 O-D] DRAMA', now: now), isEmpty);
    });

    test('picks the year nearest now', () {
      final jan = DateTime.utc(2026, 12, 31);
      expect(extractNameDates('A vs B Jan 1', now: jan),
          [DateTime.utc(2027, 1, 1)]);
    });
  });

  group('channelBaseName / channelQuality', () {
    test('groups variants', () {
      expect(channelBaseName('UK: SKY SPORTS FOOTBALL [720p]'),
          channelBaseName('UK: SKY SPORTS FOOTBALL [H265] [1080p]'));
      expect(channelBaseName('✶⋆✶ SKY SPORTS [720p] ✶⋆✶'), 'sky sports');
    });

    test('quality order', () {
      expect(channelQuality('X [4K-Q]'), greaterThan(channelQuality('X [1080p]')));
      expect(channelQuality('X [1080p]'), greaterThan(channelQuality('X [720p]')));
    });
  });

  group('channels named after the game', () {
    test('package slot with nicknames, "at" and a time but no date', () {
      expect(
          names(colts, [
            'NFL : 01 - TNF 8:15pm Colts at Texans [1080p]',
            'NFL : 02 - 1pm Dolphins at Bills [1080p]',
            'NFL : 14 - [1080p]',
          ]),
          ['NFL : 01 - TNF 8:15pm Colts at Texans [1080p]']);
    });

    test('"@" package slot (hockey) matches by nicknames', () {
      final flyers = Fixture(
        id: 'nhl:1',
        home: 'Ottawa Senators',
        away: 'Philadelphia Flyers',
        homeNames: const ['Senators'],
        awayNames: const ['Flyers'],
        homePlace: 'Ottawa',
        awayPlace: 'Philadelphia',
        kickoff: DateTime.utc(2026, 11, 20, 0, 0),
      );
      expect(
          names(flyers, [
            'NHL: 02 - 7pm Flyers @ Senators [1080p]',
            'NHL: 01 - 7pm Kings @ Maple Leafs [1080p]',
          ]),
          ['NHL: 02 - 7pm Flyers @ Senators [1080p]']);
    });

    test('full names with a written date and an ISO stamp', () {
      expect(
          names(colts, [
            'US (STREAM 263): NFL Football: 2026 Week 11 Indianapolis Colts vs. Houston Texans (2026-11-20 00:30:00) [1080p]',
          ]),
          hasLength(1));
    });

    test('the same pairing on another day is stale', () {
      expect(
          names(colts, [
            'US (STREAM 1): Indianapolis Colts vs. Houston Texans Nov 12 8:15PM ET (2026-11-12 20:15:00)',
          ]),
          isEmpty);
    });

    test('a lone nickname in a channel name is not enough', () {
      final blues = Fixture(
        id: 'nhl:2',
        home: 'Pittsburgh Penguins',
        away: 'St. Louis Blues',
        homeNames: const ['Penguins'],
        awayNames: const ['Blues'],
        homePlace: 'Pittsburgh',
        awayPlace: 'St. Louis',
        kickoff: DateTime.utc(2026, 11, 20, 0, 0),
      );
      expect(
          names(blues, [
            'USA: BLUES CLUES [1080p]',
            'USA: HILL STREET BLUES [1080p]',
            'THE PENGUINS OF MADAGASCAR',
          ]),
          isEmpty);
    });

    test('a team feed (full name, or nickname + city) is a possible match', () {
      final r = const FixtureMatcher().match(colts,
          channels: [
            ch('a', 'NHL TEAM: PHILADELPHIA FLYERS'),
            ch('b', 'NFL TEAMS: CBS COLTS INDIANAPOLIS IN'),
            ch('c', 'NFL TEAMS: CBS BEARS CHICAGO IL'),
          ],
          programmes: const [],
          now: nflNow);
      expect(r.map((m) => m.channel.id), ['b']);
      expect(r.single.strength, MatchStrength.one);
    });

    test('a different pairing of the same city names does not match', () {
      expect(
          names(colts, [
            'NFL : 07 - 1pm Steelers at Eagles [1080p]',
            'NFL : 03 - 1pm Saints at Bears [1080p]',
          ]),
          isEmpty);
    });
  });

  group('FixtureMatcher (guide)', () {
    const matcher = FixtureMatcher();

    test('guide hit with both teams is best, variants folded', () {
      final channels = [
        ch('a', 'UK: SPORT ONE [720p]'),
        ch('b', 'UK: SPORT ONE [1080p]'),
        ch('c', 'UK: NEWS [1080p]'),
      ];
      final programmes = [
        prog('a', kickoff, 'Man Utd v Arsenal'),
        prog('b', kickoff, 'Man Utd v Arsenal'),
        prog('c', kickoff, 'Evening News'),
      ];
      final r = matcher.match(fixture,
          channels: channels, programmes: programmes, now: now);
      expect(r, hasLength(1));
      expect(r.single.channel.id, 'b');
      expect(r.single.alternates, 1);
      expect(r.single.strength, MatchStrength.both);
    });

    test('a rerun hours later does not match', () {
      final r = matcher.match(fixture,
          channels: [ch('a', 'Sport')],
          programmes: [
            prog('a', kickoff.add(const Duration(hours: 5)), 'Man Utd v Arsenal',
                mins: 120)
          ],
          now: now);
      expect(r, isEmpty);
    });

    test('a programme already airing at kickoff matches', () {
      final r = matcher.match(fixture,
          channels: [ch('a', 'Sport')],
          programmes: [
            prog('a', kickoff.subtract(const Duration(minutes: 50)),
                'Arsenal v Man Utd - Preview and game')
          ],
          now: now);
      expect(r, hasLength(1));
    });

    test('one team only is "one" strength and ranks below both', () {
      final channels = [ch('a', 'Sport A'), ch('b', 'Sport B')];
      final programmes = [
        prog('a', kickoff, 'Premier League: Arsenal Live', mins: 60),
        prog('b', kickoff, 'Arsenal vs Manchester United'),
      ];
      final r = matcher.match(fixture,
          channels: channels, programmes: programmes, now: now);
      expect(r.map((m) => m.channel.id), ['b', 'a']);
      expect(r.last.strength, MatchStrength.one);
    });

    test('shows about the game only ever count as possible', () {
      final r = matcher.match(colts,
          channels: [ch('a', 'Sport A'), ch('b', 'Sport B')],
          programmes: [
            prog('a', colts.kickoff, 'Live: Colts vs Texans Pregame Show',
                mins: 30),
            prog('b', colts.kickoff, 'Colts at Texans'),
          ],
          now: nflNow);
      expect(r.map((m) => m.channel.id), ['b', 'a']);
      expect(r.first.strength, MatchStrength.both);
      expect(r.last.strength, MatchStrength.one);
    });

    test('events without two sides match by distinctive words', () {
      final race = Fixture(
          id: '3',
          home: '',
          away: '',
          eventTitle: 'Heineken Las Vegas Grand Prix',
          kickoff: kickoff);
      final r = matcher.match(race,
          channels: [ch('a', 'Racing'), ch('b', 'Other')],
          programmes: [
            prog('a', kickoff, 'Formula 1: Las Vegas Grand Prix Qualifying'),
            prog('b', kickoff, 'Grand Prix of Somewhere Else'),
          ],
          now: now);
      expect(r.map((m) => m.channel.id), ['a']);
    });

    test('alternate names count for a side', () {
      final f = Fixture(
          id: '4',
          home: 'Brighton & Hove Albion',
          away: 'Wolverhampton Wanderers',
          awayNames: const ['Wolves'],
          kickoff: kickoff);
      final r = matcher.match(f,
          channels: [ch('a', 'Sport')],
          programmes: [prog('a', kickoff, 'Brighton v Wolves')],
          now: now);
      expect(r.single.strength, MatchStrength.both);
    });

    test('favourite and catch-up break ties between equal matches', () {
      final channels = [
        ch('a', 'Alpha TV [1080p]'),
        ch('b', 'Beta TV [1080p]', fav: true),
      ];
      final programmes = [
        prog('a', kickoff, 'Man Utd v Arsenal'),
        prog('b', kickoff, 'Man Utd v Arsenal'),
      ];
      final r = matcher.match(fixture,
          channels: channels, programmes: programmes, now: now);
      expect(r.first.channel.id, 'b');
    });

    test('news "@" titles never match a fixture', () {
      final f = Fixture(
          id: '2', home: 'Four', away: 'First', kickoff: kickoff);
      final r = matcher.match(f,
          channels: [ch('a', 'Local')],
          programmes: [prog('a', kickoff, 'News @ 4')],
          now: now);
      expect(r, isEmpty);
    });
  });

  group('FixtureMatcher (guide descriptions and false positives)', () {
    const matcher = FixtureMatcher();
    final ko = colts.kickoff;

    Programme withDesc(String ch, String title, String? desc,
            {String? category}) =>
        Programme(
          channelId: ch,
          start: ko.subtract(const Duration(minutes: 5)),
          end: ko.add(const Duration(hours: 3)),
          title: title,
          description: desc,
          category: category,
        );

    List<ChannelMatch> run(List<Programme> ps) => matcher.match(colts,
        channels: [for (final p in ps) ch(p.channelId, 'Local ${p.channelId}')],
        programmes: ps,
        now: nflNow);

    test('a local station naming the teams only in the description is Best',
        () {
      final r = run([
        withDesc('wish', 'NFL Football', 'Indianapolis Colts at Houston Texans.')
      ]);
      expect(r.single.channel.id, 'wish');
      expect(r.single.strength, MatchStrength.both);
    });

    test('the same title in another market with another game is ignored', () {
      final r = run([
        withDesc('other', 'NFL Football', 'Green Bay Packers at Detroit Lions.')
      ]);
      expect(r, isEmpty);
    });

    test('one team in a non-sport programme is ignored', () {
      final r = run([withDesc('cook', 'Texans Kitchen', 'Houston recipes.')]);
      expect(r, isEmpty);
    });

    test('one full team name in a sport programme is Possible', () {
      final r = run([
        withDesc('sp', 'NFL Football', 'Indianapolis Colts take the field.')
      ]);
      expect(r.single.strength, MatchStrength.one);
    });

    test('our team against somebody else is a different game', () {
      final r = run([
        withDesc('sp', 'NFL: Houston Texans vs Tennessee Titans', null)
      ]);
      expect(r, isEmpty);
    });

    test('a lone nickname in a programme is not enough', () {
      final r = run([withDesc('sp', 'NFL Football', 'Colts fans react.')]);
      expect(r, isEmpty);
    });
  });
}
