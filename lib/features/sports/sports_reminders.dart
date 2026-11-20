import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'espn_source.dart';
import 'sports_catalog.dart';
import 'sports_models.dart';

/// Task name the shared WorkManager dispatcher routes here.
const kSportsReminderTask = 'sportsReminders';

const _kUniqueName = 'openiptv_sports_reminders';
const _kCache = 'sports_reminder_cache';
const _kCacheAt = 'sports_reminder_cache_at';
const _kNotified = 'sports_reminder_notified';
const _kChannelId = 'sports_reminders';

/// How long a fetched list of followed-team games is trusted.
const _cacheLife = Duration(hours: 6);

/// A reminder fires when kickoff is this close.
const reminderLead = Duration(
    minutes: int.fromEnvironment('OPENIPTV_SPORTS_LEAD_MINUTES',
        defaultValue: 20));

/// A followed team's game kept for the reminder worker.
class ReminderGame {
  const ReminderGame({
    required this.id,
    required this.title,
    required this.league,
    required this.kickoff,
  });

  final String id;
  final String title;
  final String league;
  final DateTime kickoff;

  Map<String, Object> toJson() => {
        'id': id,
        'title': title,
        'league': league,
        'kickoff': kickoff.millisecondsSinceEpoch,
      };

  static ReminderGame fromJson(Map<String, dynamic> j) => ReminderGame(
        id: j['id'] as String,
        title: j['title'] as String,
        league: j['league'] as String,
        kickoff: DateTime.fromMillisecondsSinceEpoch(j['kickoff'] as int,
            isUtc: true),
      );
}

/// Games to announce now: kickoff within [lead] and not already announced.
List<ReminderGame> dueReminders(
  Iterable<ReminderGame> games,
  DateTime now,
  Set<String> notified, {
  Duration lead = reminderLead,
}) =>
    [
      for (final g in games)
        if (!notified.contains(g.id) &&
            g.kickoff.isAfter(now) &&
            !g.kickoff.isAfter(now.add(lead)))
          g,
    ];

/// Registers (or cancels) the 15-minute reminder check so it matches the
/// settings: Sports on, reminders on, at least one team followed. Safe to
/// call whenever any of those change and on every start. [refetch] drops
/// the cached game list so a newly followed team is picked up.
Future<void> syncSportsReminderRegistration(AppPreferences prefs,
    {bool refetch = false}) async {
  final wanted = prefs.sportsEnabled &&
      prefs.sportsReminders &&
      prefs.sportsFollowedTeams.isNotEmpty;
  if (!wanted) {
    await Workmanager().cancelByUniqueName(_kUniqueName);
    return;
  }
  if (refetch) {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kCacheAt);
  }
  await Workmanager().registerPeriodicTask(
    _kUniqueName,
    kSportsReminderTask,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
}

Future<List<ReminderGame>> _followedGames(
    SharedPreferences p, AppPreferences prefs, DateTime now) async {
  final at = p.getInt(_kCacheAt) ?? 0;
  final fresh = now.millisecondsSinceEpoch - at < _cacheLife.inMilliseconds;
  final cached = p.getString(_kCache);
  if (fresh && cached != null) {
    return [
      for (final j in jsonDecode(cached) as List)
        ReminderGame.fromJson(j as Map<String, dynamic>),
    ];
  }

  final followed = prefs.sportsFollowedTeams.toSet();
  final ids = prefs.sportsLeagues?.toSet() ?? defaultSportsLeagueIds;
  final source = EspnSource();
  final found = <ReminderGame>[];
  final local = now.toLocal();
  var failed = false;
  for (final league in kSportsLeagues.where((l) => ids.contains(l.id))) {
    for (final offset in [0, 1]) {
      try {
        final day = DateTime(local.year, local.month, local.day + offset);
        for (final g in await source.gamesOn(league, day)) {
          if (g.hasTeams && g.involves(followed) && g.state == GameState.upcoming) {
            found.add(ReminderGame(
              id: g.id,
              title: '${g.away!.name} at ${g.home!.name}',
              league: league.name,
              kickoff: g.kickoff,
            ));
          }
        }
      } catch (_) {
        failed = true;
      }
    }
  }
  // Only remember a complete answer; after a failure try again next run.
  if (!failed) {
    await p.setString(_kCache, jsonEncode([for (final g in found) g.toJson()]));
    await p.setInt(_kCacheAt, now.millisecondsSinceEpoch);
  }
  return found;
}

/// The reminder worker body (runs in WorkManager's background isolate).
Future<bool> runSportsReminderCheck() async {
  final p = await SharedPreferences.getInstance();
  await p.reload();
  final prefs = AppPreferences(p);
  if (!prefs.sportsEnabled ||
      !prefs.sportsReminders ||
      prefs.sportsFollowedTeams.isEmpty) {
    return true;
  }
  final now = DateTime.now().toUtc();
  final games = await _followedGames(p, prefs, now);
  final notified = (p.getStringList(_kNotified) ?? const <String>[]).toSet();
  final due = dueReminders(games, now, notified);
  debugPrint('[OTV-sports] reminder check: ${games.length} followed games, '
      '${due.length} due');
  if (due.isEmpty) return true;

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
      settings: const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_stat_open_iptv')));
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
        _kChannelId,
        'Sports reminders',
        description: 'Kickoff reminders for the teams you follow',
        importance: Importance.defaultImportance,
      ));
  for (final g in due) {
    final mins = g.kickoff.difference(now).inMinutes.clamp(1, 99);
    await plugin.show(
      id: 1000 + (g.id.hashCode & 0xfffff),
      title: 'Kickoff in $mins min',
      body: '${g.title} · ${g.league}',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _kChannelId,
          'Sports reminders',
          channelDescription: 'Kickoff reminders for the teams you follow',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
    notified.add(g.id);
  }
  // Keep the list short: only ids that can still matter.
  final live = games.map((g) => g.id).toSet();
  await p.setStringList(
      _kNotified, notified.where(live.contains).toList());
  return true;
}
