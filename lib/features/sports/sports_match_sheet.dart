import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/live_tv/catchup_launcher.dart';
import 'package:open_iptv/features/player/player_ui.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

import 'fixture_matcher.dart';
import 'sports_models.dart';
import 'sports_providers.dart';
import 'sports_screen.dart' show sportsRevealedProvider;

/// Opens the sheet of best-matched channels for [game].
Future<void> showMatchSheet(BuildContext context, WidgetRef ref, Game game) {
  return showPlayerSheet<void>(
    context,
    (sheetContext) => _MatchSheet(
      game: game,
      onPlay: (m) async {
        Navigator.of(sheetContext).pop();
        if (!context.mounted) return;
        await _play(context, ref, game, m);
      },
      onSearch: () {
        Navigator.of(sheetContext).pop();
        if (context.mounted) context.go('/search');
      },
    ),
  );
}

bool _isCatchup(Game game, ChannelMatch m) {
  final p = m.programme;
  return game.state == GameState.finished &&
      p != null &&
      m.channel.hasCatchup &&
      !p.end.isAfter(DateTime.now());
}

Future<void> _play(
    BuildContext context, WidgetRef ref, Game game, ChannelMatch m) async {
  final c = m.channel;
  if (_isCatchup(game, m)) {
    final source =
        await ref.read(appDatabaseProvider).getSourceById(c.sourceId);
    if (source == null || !context.mounted) return;
    await launchCatchup(
      context: context,
      ref: ref,
      channel: c,
      source: source,
      programme: m.programme!,
      replace: false,
    );
    return;
  }
  void live() => context.push('/player', extra: {
        'streamUrl': c.streamUrl,
        'title': c.name,
        'contentType': 'live',
        'contentId': c.id,
      });
  unawaited(openChannelWithStartChoice(
    context: context,
    ref: ref,
    channel: c,
    programme: m.programme,
    playLive: live,
  ));
}

class _MatchSheet extends ConsumerWidget {
  const _MatchSheet({
    required this.game,
    required this.onPlay,
    required this.onSearch,
  });

  final Game game;
  final void Function(ChannelMatch) onPlay;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final matches = ref.watch(gameMatchesProvider(game));
    final followed = ref.watch(sportsFollowedProvider);
    final hide = ref.watch(sportsHideScoresProvider) &&
        !ref.watch(sportsRevealedProvider).contains(game.id);

    final when = game.state == GameState.upcoming
        ? DateFormat('E d MMM, h:mm a').format(game.kickoff.toLocal())
        : game.statusText;
    final scoreLine = game.hasTeams && game.state != GameState.upcoming
        ? (hide
            ? null
            : '${game.away!.score ?? ''} – ${game.home!.score ?? ''}')
        : null;

    Widget followChip(GameTeam t) {
      final on = followed.contains(t.name);
      return TvActivatable(
        onTap: () async {
          final prefs = await ref.read(appPreferencesProvider.future);
          await setSportsFollowed(ref, t.name, !on, prefs);
        },
        borderRadius: BorderRadius.circular(20),
        builder: (tap) => FilterChip(
          avatar: Icon(on ? Icons.star : Icons.star_border, size: 18),
          label: Text(on ? 'Following ${t.name}' : 'Follow ${t.name}'),
          selected: on,
          onSelected: tap == null ? null : (_) => tap(),
        ),
      );
    }

    final list = matches.value;
    final shown = [
      for (final m in list ?? const <ChannelMatch>[])
        // A finished game is only worth opening where catch-up can play it.
        if (game.state != GameState.finished || _isCatchup(game, m)) m,
    ];

    return PlayerSheet(
      title: game.hasTeams ? '${game.away!.name} at ${game.home!.name}' : game.title,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            [game.league.name, if (when.isNotEmpty) when, if (scoreLine != null) scoreLine]
                .join(' · '),
            style: theme.textTheme.bodyMedium!
                .copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        if (hide && game.state != GameState.upcoming && game.hasTeams)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TvActivatable(
              onTap: () => ref
                  .read(sportsRevealedProvider.notifier)
                  .update((s) => {...s, game.id}),
              builder: (tap) => TextButton.icon(
                onPressed: tap,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Show score'),
              ),
            ),
          ),
        if (game.hasTeams)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              children: [followChip(game.home!), followChip(game.away!)],
            ),
          ),
        const Divider(height: 24),
        if (list == null && !matches.hasError)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Row(children: [
              SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 16),
              Text('Looking through your channels…'),
            ]),
          )
        else if (matches.hasError)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text("Couldn't search your channels. Try again in a moment."),
          )
        else if (shown.isEmpty)
          _NoMatch(game: game, onSearch: onSearch)
        else ...[
          for (var i = 0; i < shown.length; i++)
            _MatchRow(
              game: game,
              match: shown[i],
              autofocus: i == 0,
              onTap: () => onPlay(shown[i]),
            ),
        ],
      ],
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.game, required this.onSearch});

  final Game game;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(game.state == GameState.finished
                ? 'No catch-up found for this game.'
                : 'No channels found for this game.'),
            const SizedBox(height: 12),
            TvActivatable(
              autofocus: true,
              onTap: onSearch,
              builder: (tap) => OutlinedButton.icon(
                onPressed: tap,
                icon: const Icon(Icons.search),
                label: const Text('Search your channels'),
              ),
            ),
          ],
        ),
      );
}

class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.game,
    required this.match,
    required this.onTap,
    this.autofocus = false,
  });

  final Game game;
  final ChannelMatch match;
  final VoidCallback onTap;
  final bool autofocus;

  String get _label {
    if (match.strength == MatchStrength.one) return 'Possible';
    return game.state == GameState.upcoming ? 'Likely' : 'Best';
  }

  String _reason(BuildContext context) {
    final p = match.programme;
    final parts = <String>[];
    if (match.source == MatchSource.channelName) {
      parts.add('Named for this game');
    } else if (p != null) {
      final t = DateFormat.jm().format(p.start.toLocal());
      parts.add(_isCatchup(game, match)
          ? 'Catch-up · $t'
          : (p.isLive ? 'On the guide now' : 'On the guide · $t'));
    }
    final group = match.channel.groupTitle;
    if (group != null && group.isNotEmpty) parts.add(context.displayName(group));
    if (match.alternates > 0) {
      parts.add('${match.alternates} other version'
          '${match.alternates == 1 ? '' : 's'}');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Channel c = match.channel;
    return TvActivatable(
      autofocus: autofocus,
      onTap: onTap,
      builder: (tap) => ListTile(
        leading: const Icon(Icons.live_tv_outlined),
        title: Text(context.displayName(c.name),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(_reason(context), style: theme.textTheme.bodySmall),
        trailing: Chip(
          label: Text(_label),
          visualDensity: VisualDensity.compact,
        ),
        onTap: tap,
      ),
    );
  }
}
