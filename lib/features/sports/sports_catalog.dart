import 'sports_models.dart';

/// Leagues offered in Settings → Sports. Ids are stored in preferences, so
/// never rename one.
const kSportsLeagues = <SportsLeague>[
  SportsLeague(
      id: 'eng.1',
      name: 'Premier League',
      group: SportGroup.football,
      espnPath: 'soccer/eng.1',
      onByDefault: true),
  SportsLeague(
      id: 'uefa.champions',
      name: 'Champions League',
      group: SportGroup.football,
      espnPath: 'soccer/uefa.champions',
      onByDefault: true),
  SportsLeague(
      id: 'uefa.europa',
      name: 'Europa League',
      group: SportGroup.football,
      espnPath: 'soccer/uefa.europa'),
  SportsLeague(
      id: 'eng.2',
      name: 'Championship',
      group: SportGroup.football,
      espnPath: 'soccer/eng.2'),
  SportsLeague(
      id: 'esp.1',
      name: 'La Liga',
      group: SportGroup.football,
      espnPath: 'soccer/esp.1'),
  SportsLeague(
      id: 'ger.1',
      name: 'Bundesliga',
      group: SportGroup.football,
      espnPath: 'soccer/ger.1'),
  SportsLeague(
      id: 'ita.1',
      name: 'Serie A',
      group: SportGroup.football,
      espnPath: 'soccer/ita.1'),
  SportsLeague(
      id: 'fra.1',
      name: 'Ligue 1',
      group: SportGroup.football,
      espnPath: 'soccer/fra.1'),
  SportsLeague(
      id: 'usa.1',
      name: 'MLS',
      group: SportGroup.football,
      espnPath: 'soccer/usa.1'),
  SportsLeague(
      id: 'nfl',
      name: 'NFL',
      group: SportGroup.american,
      espnPath: 'football/nfl',
      onByDefault: true),
  SportsLeague(
      id: 'nba',
      name: 'NBA',
      group: SportGroup.american,
      espnPath: 'basketball/nba',
      onByDefault: true),
  SportsLeague(
      id: 'mlb',
      name: 'MLB',
      group: SportGroup.american,
      espnPath: 'baseball/mlb'),
  SportsLeague(
      id: 'nhl',
      name: 'NHL',
      group: SportGroup.american,
      espnPath: 'hockey/nhl',
      onByDefault: true),
  SportsLeague(
      id: 'college-football',
      name: 'College football',
      group: SportGroup.american,
      espnPath: 'football/college-football'),
  SportsLeague(
      id: 'f1',
      name: 'Formula 1',
      group: SportGroup.other,
      espnPath: 'racing/f1',
      onByDefault: true),
  SportsLeague(
      id: 'ufc',
      name: 'UFC',
      group: SportGroup.other,
      espnPath: 'mma/ufc',
      onByDefault: true),
  SportsLeague(
      id: 'atp',
      name: 'Tennis (ATP)',
      group: SportGroup.other,
      espnPath: 'tennis/atp'),
  SportsLeague(
      id: 'wta',
      name: 'Tennis (WTA)',
      group: SportGroup.other,
      espnPath: 'tennis/wta'),
];

SportsLeague? sportsLeagueById(String id) {
  for (final l in kSportsLeagues) {
    if (l.id == id) return l;
  }
  return null;
}

/// The leagues switched on for a fresh install of Sports.
Set<String> get defaultSportsLeagueIds =>
    {for (final l in kSportsLeagues) if (l.onByDefault) l.id};
