import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_iptv/core/services/auto_refresh_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/widgets/settings_group.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

import 'sports_catalog.dart';
import 'sports_models.dart';
import 'sports_providers.dart';

/// Settings → Sports: the master switch, leagues, followed teams.
class SportsSettingsScreen extends ConsumerWidget {
  const SportsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(appPreferencesProvider).value;
    final enabled = ref.watch(sportsEnabledProvider);
    final leagues = ref.watch(sportsLeaguesProvider);
    final followed = ref.watch(sportsFollowedProvider).toList()..sort();
    final hide = ref.watch(sportsHideScoresProvider);
    final reminders = ref.watch(sportsRemindersProvider);

    Widget toggle({
      required IconData icon,
      required String title,
      String? subtitle,
      required bool value,
      required Future<void> Function(AppPreferences, bool) set,
      bool autofocus = false,
    }) =>
        TvActivatable(
          autofocus: autofocus,
          onTap: prefs == null ? null : () => set(prefs, !value),
          builder: (_) => SwitchListTile(
            secondary: IconBadge(icon: icon),
            title: Text(title),
            subtitle: subtitle == null
                ? null
                : Text(subtitle, style: theme.textTheme.bodySmall),
            value: value,
            onChanged: prefs == null ? null : (v) => set(prefs, v),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Sports')),
      body: TvFollowFocus(
        focusFirst: true,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SettingsGroup(
              title: '',
              children: [
                toggle(
                  autofocus: true,
                  icon: Icons.sports_soccer_outlined,
                  title: 'Show Sports (experimental)',
                  subtitle:
                      'Adds a Sports tab with fixtures and live scores. Tap a '
                      'game to see which of your channels are showing it. '
                      'Turning it on makes the app ask a free public '
                      'scoreboard for games; nothing about your playlists or '
                      'profile is sent.',
                  value: enabled,
                  set: (p, v) async {
                    if (v && !enabled) {
                      final ok = await _confirmExperimental(context);
                      if (!ok) return;
                    }
                    await setSportsEnabled(ref, v, p);
                  },
                ),
              ],
            ),
            if (enabled) ...[
              SettingsGroup(title: 'Scores', children: [
                toggle(
                  icon: Icons.visibility_off_outlined,
                  title: 'Hide scores',
                  subtitle:
                      'Show a dash instead of the score, for games you watch '
                      'later. Hold a game to reveal it.',
                  value: hide,
                  set: (p, v) => setSportsHideScores(ref, v, p),
                ),
              ]),
              SettingsGroup(title: 'Reminders', children: [
                toggle(
                  icon: Icons.notifications_outlined,
                  title: 'Kickoff reminders',
                  subtitle: 'A notification shortly before a followed team '
                      'plays. Checked about every 15 minutes, so timing is '
                      'approximate.',
                  value: reminders,
                  set: (p, v) async {
                    if (v) await requestNotificationPermission();
                    await setSportsReminders(ref, v, p);
                  },
                ),
              ]),
              for (final group in SportGroup.values)
                SettingsGroup(title: group.label, children: [
                  for (final l in kSportsLeagues)
                    if (l.group == group)
                      TvActivatable(
                        onTap: prefs == null
                            ? null
                            : () => setSportsLeague(
                                ref, l.id, !leagues.contains(l.id), prefs),
                        builder: (_) => SwitchListTile(
                          title: Text(l.name),
                          value: leagues.contains(l.id),
                          onChanged: prefs == null
                              ? null
                              : (v) => setSportsLeague(ref, l.id, v, prefs),
                        ),
                      ),
                ]),
              SettingsGroup(
                title: 'Followed teams',
                description: followed.isEmpty
                    ? 'Follow a team from any game and its games are listed first.'
                    : null,
                children: [
                  for (final t in followed)
                    ListTile(
                      leading: const IconBadge(icon: Icons.star_outline),
                      title: Text(t),
                      trailing: TvActivatable(
                        round: true,
                        onTap: prefs == null
                            ? null
                            : () => setSportsFollowed(ref, t, false, prefs),
                        builder: (tap) => IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: theme.colorScheme.error),
                          tooltip: 'Unfollow',
                          onPressed: tap,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One-time-per-enable notice: Sports is an experimental feature.
Future<bool> _confirmExperimental(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.science_outlined),
      title: const Text('Experimental feature'),
      content: const Text(
        'Sports is new and still being tested. Games and scores come from a '
        'free public scoreboard that can change or go down, and channel '
        'matches are best guesses, so some games may show no channel or the '
        'wrong one. Kickoff reminders are approximate.\n\n'
        'Turning it on contacts that scoreboard (only your device address is '
        'shared). Please report problems on GitHub Issues.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Turn on'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
