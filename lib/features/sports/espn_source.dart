import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'sports_models.dart';

/// Where fixtures and scores come from. The free source is ESPN's public
/// scoreboard; a source that uses the user's own API key can sit behind the
/// same interface later.
abstract interface class SportsSource {
  /// Every game of [league] on [day] (a local calendar date).
  Future<List<Game>> gamesOn(SportsLeague league, DateTime day);
}

class EspnSource implements SportsSource {
  EspnSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://site.api.espn.com/apis/site/v2/sports';

  @override
  Future<List<Game>> gamesOn(SportsLeague league, DateTime day) async {
    final d = '${day.year.toString().padLeft(4, '0')}'
        '${day.month.toString().padLeft(2, '0')}'
        '${day.day.toString().padLeft(2, '0')}';
    final uri = Uri.parse('$_base/${league.espnPath}/scoreboard?dates=$d');
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}', uri);
    }
    return parseEspnScoreboard(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
        league);
  }
}

/// Turns ESPN's scoreboard JSON into games. Unknown or odd entries are
/// skipped rather than failing the whole league.
@visibleForTesting
List<Game> parseEspnScoreboard(Map<String, dynamic> json, SportsLeague league) {
  final games = <Game>[];
  for (final e in (json['events'] as List? ?? const [])) {
    try {
      final g = _parseEvent(e as Map<String, dynamic>, league);
      if (g != null) games.add(g);
    } catch (_) {
      // One malformed event must not hide the rest.
    }
  }
  return games;
}

GameTeam? _team(Map<String, dynamic> competitor) {
  final t = competitor['team'] as Map<String, dynamic>?;
  if (t == null) return null;
  final name = t['displayName'] as String? ?? t['name'] as String?;
  if (name == null) return null;
  return GameTeam(
    name: name,
    shortName: t['shortDisplayName'] as String?,
    abbreviation: t['abbreviation'] as String?,
    location: t['location'] as String?,
    nickname: t['name'] as String?,
    logoUrl: t['logo'] as String?,
    score: competitor['score']?.toString(),
  );
}

Game? _parseEvent(Map<String, dynamic> e, SportsLeague league) {
  final kickoff = DateTime.tryParse(e['date'] as String? ?? '')?.toUtc();
  if (kickoff == null) return null;
  final status = (e['status'] as Map<String, dynamic>?)?['type']
      as Map<String, dynamic>?;
  final state = switch (status?['state']) {
    'in' => GameState.live,
    'post' => GameState.finished,
    _ => GameState.upcoming,
  };
  final statusText = (status?['shortDetail'] ?? status?['description'] ?? '')
      .toString();

  GameTeam? home;
  GameTeam? away;
  final comps = e['competitions'] as List? ?? const [];
  if (comps.isNotEmpty) {
    for (final c in ((comps.first as Map)['competitors'] as List? ?? const [])) {
      final m = c as Map<String, dynamic>;
      final team = _team(m);
      if (m['homeAway'] == 'home') home = team;
      if (m['homeAway'] == 'away') away = team;
    }
  }
  final name = e['name'] as String? ?? e['shortName'] as String? ?? '';
  if (home == null || away == null) {
    home = null;
    away = null;
    if (name.isEmpty) return null;
  }
  return Game(
    id: '${league.id}:${e['id']}',
    league: league,
    kickoff: kickoff,
    state: state,
    statusText: statusText,
    title: name,
    home: home,
    away: away,
  );
}
