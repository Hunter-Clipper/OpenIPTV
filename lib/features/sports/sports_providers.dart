import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';

import 'espn_source.dart';
import 'fixture_matcher.dart';
import 'sports_catalog.dart';
import 'sports_models.dart';
import 'sports_reminders.dart';

// ---------------------------------------------------------------------------
// Settings (synced from preferences at start-up, like the other settings)
// ---------------------------------------------------------------------------

/// The master switch: off means no tab and no network calls to a sports
/// source.
final sportsEnabledProvider = StateProvider<bool>((ref) => false);
final sportsLeaguesProvider =
    StateProvider<Set<String>>((ref) => defaultSportsLeagueIds);
final sportsFollowedProvider = StateProvider<Set<String>>((ref) => const {});
final sportsHideScoresProvider = StateProvider<bool>((ref) => false);
final sportsRemindersProvider = StateProvider<bool>((ref) => false);

void syncSportsSettings(WidgetRef ref, AppPreferences prefs) {
  ref.read(sportsEnabledProvider.notifier).state = prefs.sportsEnabled;
  ref.read(sportsLeaguesProvider.notifier).state =
      prefs.sportsLeagues?.toSet() ?? defaultSportsLeagueIds;
  ref.read(sportsFollowedProvider.notifier).state =
      prefs.sportsFollowedTeams.toSet();
  ref.read(sportsHideScoresProvider.notifier).state = prefs.sportsHideScores;
  ref.read(sportsRemindersProvider.notifier).state = prefs.sportsReminders;
}

Future<void> setSportsEnabled(
    WidgetRef ref, bool on, AppPreferences prefs) async {
  ref.read(sportsEnabledProvider.notifier).state = on;
  await prefs.setSportsEnabled(on);
  await syncSportsReminderRegistration(prefs);
}

Future<void> setSportsLeague(
    WidgetRef ref, String id, bool on, AppPreferences prefs) async {
  final next = {...ref.read(sportsLeaguesProvider)};
  on ? next.add(id) : next.remove(id);
  ref.read(sportsLeaguesProvider.notifier).state = next;
  await prefs.setSportsLeagues(next.toList());
}

Future<void> setSportsFollowed(
    WidgetRef ref, String team, bool follow, AppPreferences prefs) async {
  final next = {...ref.read(sportsFollowedProvider)};
  follow ? next.add(team) : next.remove(team);
  ref.read(sportsFollowedProvider.notifier).state = next;
  await prefs.setSportsFollowedTeams(next.toList());
  await syncSportsReminderRegistration(prefs, refetch: true);
}

Future<void> setSportsHideScores(
    WidgetRef ref, bool on, AppPreferences prefs) async {
  ref.read(sportsHideScoresProvider.notifier).state = on;
  await prefs.setSportsHideScores(on);
}

Future<void> setSportsReminders(
    WidgetRef ref, bool on, AppPreferences prefs) async {
  ref.read(sportsRemindersProvider.notifier).state = on;
  await prefs.setSportsReminders(on);
  await syncSportsReminderRegistration(prefs, refetch: true);
}

/// Whether the Sports tab shows: switched on, and not a kids profile.
final sportsTabVisibleProvider = Provider<bool>((ref) {
  final on = ref.watch(sportsEnabledProvider);
  final kids =
      ref.watch(activeProfileProvider.select((p) => p.value?.isKidsProfile));
  return on && kids != true;
});

// ---------------------------------------------------------------------------
// Games
// ---------------------------------------------------------------------------

final sportsSourceProvider = Provider<SportsSource>((ref) => EspnSource());

class DayGames {
  const DayGames(this.games, {this.failedLeagues = 0});
  final List<Game> games;

  /// Leagues whose request failed (the rest are still shown).
  final int failedLeagues;
}

/// Games on a local calendar day for the selected leagues. Cached for a
/// minute so flipping between day chips doesn't refetch; the screen
/// invalidates it on a timer while today is open (live scores).
final sportsGamesProvider =
    FutureProvider.autoDispose.family<DayGames, DateTime>((ref, day) async {
  final link = ref.keepAlive();
  final t = Timer(const Duration(minutes: 1), link.close);
  ref.onDispose(t.cancel);

  if (!ref.watch(sportsEnabledProvider)) return const DayGames([]);
  final ids = ref.watch(sportsLeaguesProvider);
  final source = ref.read(sportsSourceProvider);
  var failed = 0;
  final lists = await Future.wait([
    for (final l in kSportsLeagues)
      if (ids.contains(l.id))
        source.gamesOn(l, day).catchError((Object _) {
          failed++;
          return <Game>[];
        }),
  ]);
  final seen = <String>{};
  final games = [
    for (final list in lists)
      for (final g in list)
        if (seen.add(g.id)) g,
  ]..sort((a, b) => a.kickoff.compareTo(b.kickoff));
  return DayGames(games, failedLeagues: failed);
});

// ---------------------------------------------------------------------------
// Matching a game to the user's channels
// ---------------------------------------------------------------------------

/// Words worth searching the guide for, for a game.
List<String> searchTermsFor(Game g) {
  if (g.hasTeams) {
    return {
      for (final t in [g.home!, g.away!])
        for (final n in [t.name, ...t.otherNames])
          if (n.length >= 4) n,
    }.toList();
  }
  final words = g.title
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((w) => w.length > 3)
      .toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  return words.take(2).toList();
}

final gameMatchesProvider = FutureProvider.autoDispose
    .family<List<ChannelMatch>, Game>((ref, game) async {
  final db = ref.read(appDatabaseProvider);
  final sourceId = ref.read(activeSourceIdProvider);
  final prefs = ref.read(appPreferencesProvider).value;
  final unlocked = ref.read(parentalSessionUnlockedProvider);

  final from = game.kickoff.subtract(const Duration(hours: 3));
  final to = game.kickoff.add(const Duration(hours: 1));
  final programmes =
      await db.searchProgrammesWithText(searchTermsFor(game), from, to);

  final ids = programmes.map((p) => p.channelId).toSet().toList();
  final byId = <String, Channel>{};
  for (var i = 0; i < ids.length; i += 400) {
    final chunk = ids.sublist(i, i + 400 > ids.length ? ids.length : i + 400);
    for (final c in await db.getChannelsByIds(chunk, sourceId: sourceId)) {
      byId[c.id] = c;
    }
  }
  for (final c in await db.getChannelsNamedLike(searchTermsFor(game),
      sourceId: sourceId)) {
    byId[c.id] = c;
  }

  final usable = [
    for (final c in byId.values)
      if (!isAdultGenre(c.groupTitle) &&
          (prefs == null || !isGenreLocked(c.groupTitle, prefs, unlocked)))
        c,
  ];
  final matches = const FixtureMatcher().match(
    game.toFixture(),
    channels: usable,
    programmes: programmes,
    now: DateTime.now().toUtc(),
  );
  debugPrint('[OTV-sports] ${game.title}: ${programmes.length} guide hits, '
      '${usable.length} channels checked, ${matches.length} matches');
  for (final m in matches.take(12)) {
    debugPrint('[OTV-sports]   ${m.strength.name}/${m.source.name} '
        '"${m.channel.name}" ${m.programme?.title ?? ''}');
  }
  return matches;
});
