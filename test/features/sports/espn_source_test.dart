import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/features/sports/espn_source.dart';
import 'package:open_iptv/features/sports/sports_catalog.dart';
import 'package:open_iptv/features/sports/sports_models.dart';

void main() {
  final epl = sportsLeagueById('eng.1')!;
  final f1 = sportsLeagueById('f1')!;

  test('parses a two-sided game with scores and live state', () {
    final games = parseEspnScoreboard({
      'events': [
        {
          'id': '1',
          'date': '2026-11-21T12:30Z',
          'name': 'Fulham at Manchester City',
          'status': {
            'type': {'state': 'in', 'shortDetail': "45'"}
          },
          'competitions': [
            {
              'competitors': [
                {
                  'homeAway': 'home',
                  'score': '2',
                  'team': {
                    'displayName': 'Manchester City',
                    'shortDisplayName': 'Man City',
                    'abbreviation': 'MCI'
                  }
                },
                {
                  'homeAway': 'away',
                  'score': '1',
                  'team': {'displayName': 'Fulham', 'abbreviation': 'FUL'}
                },
              ]
            }
          ]
        }
      ]
    }, epl);
    final g = games.single;
    expect(g.id, 'eng.1:1');
    expect(g.state, GameState.live);
    expect(g.home!.name, 'Manchester City');
    expect(g.home!.score, '2');
    expect(g.away!.score, '1');
    expect(g.kickoff, DateTime.utc(2026, 11, 21, 12, 30));
    expect(g.toFixture().homeNames, ['Man City']);
  });

  test('an event without two sides keeps its title', () {
    final g = parseEspnScoreboard({
      'events': [
        {
          'id': '9',
          'date': '2026-11-20T00:30Z',
          'name': 'Las Vegas Grand Prix',
          'status': {
            'type': {'state': 'pre', 'shortDetail': '11/19 - 7:30 PM EST'}
          },
          'competitions': [
            {'competitors': []}
          ]
        }
      ]
    }, f1).single;
    expect(g.hasTeams, isFalse);
    expect(g.state, GameState.upcoming);
    expect(g.toFixture().eventTitle, 'Las Vegas Grand Prix');
  });

  test('a malformed event is skipped, the rest are kept', () {
    final games = parseEspnScoreboard({
      'events': [
        {'id': 'bad'},
        {
          'id': '2',
          'date': '2026-11-21T12:30Z',
          'name': 'Event',
          'status': {
            'type': {'state': 'post'}
          },
        }
      ]
    }, f1);
    expect(games, hasLength(1));
    expect(games.single.state, GameState.finished);
  });

  test('every league id is unique', () {
    final ids = kSportsLeagues.map((l) => l.id).toSet();
    expect(ids.length, kSportsLeagues.length);
  });
}
