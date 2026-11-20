import 'fixture_matcher.dart';

/// How leagues are grouped in Settings → Sports.
enum SportGroup {
  football('Football'),
  american('American sports'),
  other('Motorsport, combat & tennis');

  const SportGroup(this.label);
  final String label;
}

/// A league or competition the user can switch on.
class SportsLeague {
  const SportsLeague({
    required this.id,
    required this.name,
    required this.group,
    required this.espnPath,
    this.onByDefault = false,
  });

  /// Stable id stored in preferences.
  final String id;
  final String name;
  final SportGroup group;

  /// `sport/league` in ESPN's scoreboard URL.
  final String espnPath;
  final bool onByDefault;
}

enum GameState { upcoming, live, finished }

class GameTeam {
  const GameTeam({
    required this.name,
    this.shortName,
    this.abbreviation,
    this.location,
    this.nickname,
    this.logoUrl,
    this.score,
  });

  final String name;
  final String? shortName;
  final String? abbreviation;

  /// The city or region ("Indianapolis") and the nickname ("Colts").
  final String? location;
  final String? nickname;
  final String? logoUrl;
  final String? score;

  /// Other names worth searching for. Abbreviations are left out: three
  /// letters match far too much.
  List<String> get otherNames => [
        if (shortName != null && shortName != name) shortName!,
        if (nickname != null && nickname != name && nickname != shortName)
          nickname!,
      ];
}

/// One game or event on the Fixtures tab.
class Game {
  const Game({
    required this.id,
    required this.league,
    required this.kickoff,
    required this.state,
    required this.statusText,
    required this.title,
    this.home,
    this.away,
  });

  final String id;
  final SportsLeague league;

  /// UTC.
  final DateTime kickoff;
  final GameState state;

  /// "Scheduled", "45'", "Final", "Q3 4:12"...
  final String statusText;

  /// Event name; for two-sided games, "Away at Home".
  final String title;
  final GameTeam? home;
  final GameTeam? away;

  bool get hasTeams => home != null && away != null;

  // A game is its id: scores and status change, the game does not (this is
  // also the provider family key for its channel matches).
  @override
  bool operator ==(Object other) => other is Game && other.id == id;

  @override
  int get hashCode => id.hashCode;

  bool involves(Set<String> followed) =>
      followed.contains(home?.name) || followed.contains(away?.name);

  Fixture toFixture() => Fixture(
        id: id,
        home: home?.name ?? '',
        away: away?.name ?? '',
        homeNames: home?.otherNames ?? const [],
        awayNames: away?.otherNames ?? const [],
        homePlace: home?.location,
        awayPlace: away?.location,
        eventTitle: hasTeams ? '' : title,
        kickoff: kickoff,
        league: league.name,
      );
}
