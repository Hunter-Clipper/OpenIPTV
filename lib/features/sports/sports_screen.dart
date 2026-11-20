import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_iptv/shared/widgets/empty_state_view.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

import 'sports_catalog.dart';
import 'sports_match_sheet.dart';
import 'sports_models.dart';
import 'sports_providers.dart';

/// Games whose score the user chose to show although "Hide scores" is on.
final sportsRevealedProvider =
    StateProvider<Set<String>>((ref) => const {});

/// The Sports tab: fixtures and live scores; tap a game for channels.
class SportsScreen extends ConsumerStatefulWidget {
  const SportsScreen({super.key});

  @override
  ConsumerState<SportsScreen> createState() => _SportsScreenState();
}

class _SportsScreenState extends ConsumerState<SportsScreen> {
  /// 0 = today; the strip runs from yesterday (-1) to six days ahead.
  int _offset = 0;
  String? _leagueId;
  Timer? _refresh;

  DateTime get _day {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + _offset);
  }

  @override
  void initState() {
    super.initState();
    // Live scores: refresh while today is showing.
    _refresh = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted && _offset == 0) ref.invalidate(sportsGamesProvider(_day));
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  String _dayLabel(int offset) {
    if (offset == -1) return 'Yesterday';
    if (offset == 0) return 'Today';
    if (offset == 1) return 'Tomorrow';
    final n = DateTime.now();
    return DateFormat('E d')
        .format(DateTime(n.year, n.month, n.day + offset));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(sportsEnabledProvider);
    final selected = ref.watch(sportsLeaguesProvider);
    final followed = ref.watch(sportsFollowedProvider);
    final async = ref.watch(sportsGamesProvider(_day));
    final data = async.value;

    final leagues = [
      for (final l in kSportsLeagues)
        if (selected.contains(l.id)) l,
    ];
    if (_leagueId != null && !selected.contains(_leagueId)) _leagueId = null;

    Widget body;
    if (!enabled || leagues.isEmpty) {
      body = EmptyStateView(
        icon: Icons.sports_soccer_outlined,
        title: enabled ? 'No leagues selected' : 'Sports is off',
        message: enabled
            ? 'Choose the leagues you follow in Settings → Sports.'
            : 'Turn it on in Settings → Sports.',
        actionLabel: 'Open Sports settings',
        onAction: () => context.push('/settings/sports'),
      );
    } else if (data == null) {
      body = async.hasError
          ? EmptyStateView(
              icon: Icons.cloud_off_outlined,
              title: "Couldn't load games",
              message: 'Check your connection and try again.',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(sportsGamesProvider(_day)),
            )
          : const LoadingView();
    } else {
      final games = [
        for (final g in data.games)
          if (_leagueId == null || g.league.id == _leagueId) g,
      ];
      body = RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sportsGamesProvider(_day));
          await ref.read(sportsGamesProvider(_day).future);
        },
        child: _GameList(
          games: games,
          followed: followed,
          failedLeagues: data.failedLeagues,
          dayLabel: _dayLabel(_offset),
          onOpen: (g) => showMatchSheet(context, ref, g),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sports')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (var o = -1; o <= 6; o++)
                  _Chip(
                    label: _dayLabel(o),
                    selected: o == _offset,
                    autofocus: o == 0,
                    onTap: () => setState(() => _offset = o),
                  ),
              ],
            ),
          ),
          if (leagues.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  _Chip(
                    label: 'All',
                    selected: _leagueId == null,
                    onTap: () => setState(() => _leagueId = null),
                  ),
                  for (final l in leagues)
                    _Chip(
                      label: l.name,
                      selected: _leagueId == l.id,
                      onTap: () => setState(() => _leagueId = l.id),
                    ),
                ],
              ),
            ),
          Expanded(child: TvFollowFocus(child: body)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.autofocus = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TvActivatable(
          onTap: onTap,
          autofocus: autofocus,
          borderRadius: BorderRadius.circular(20),
          builder: (tap) => ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: tap == null ? null : (_) => tap(),
          ),
        ),
      );
}

class _GameList extends ConsumerWidget {
  const _GameList({
    required this.games,
    required this.followed,
    required this.failedLeagues,
    required this.dayLabel,
    required this.onOpen,
  });

  final List<Game> games;
  final Set<String> followed;
  final int failedLeagues;
  final String dayLabel;
  final void Function(Game) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (games.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 64),
        EmptyStateView(
          icon: Icons.event_busy_outlined,
          title: 'No games',
          message: failedLeagues > 0
              ? "Some leagues couldn't be loaded. Pull down to try again."
              : 'Nothing scheduled for $dayLabel in your leagues.',
        ),
      ]);
    }

    final live = [for (final g in games) if (g.state == GameState.live) g];
    final following = [
      for (final g in games)
        if (g.state != GameState.live && g.involves(followed)) g,
    ];
    final rest = [
      for (final g in games)
        if (g.state != GameState.live && !g.involves(followed)) g,
    ];
    final byLeague = <SportsLeague, List<Game>>{};
    for (final g in rest) {
      byLeague.putIfAbsent(g.league, () => []).add(g);
    }

    final items = <Widget>[];
    void section(String title, List<Game> list) {
      if (list.isEmpty) return;
      items.add(_Header(title));
      for (final g in list) {
        items.add(_GameRow(game: g, onTap: () => onOpen(g)));
      }
    }

    section('Live now', live);
    section('Following', following);
    for (final e in byLeague.entries) {
      section(e.key.name, e.value);
    }
    if (failedLeagues > 0) {
      items.add(Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          "Some leagues couldn't be loaded. Pull down to try again.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ));
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: items,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
        child: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall!
              .copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      );
}

class _GameRow extends ConsumerWidget {
  const _GameRow({required this.game, required this.onTap});

  final Game game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hide = ref.watch(sportsHideScoresProvider) &&
        !ref.watch(sportsRevealedProvider).contains(game.id);
    final live = game.state == GameState.live;
    final showScores = game.hasTeams && game.state != GameState.upcoming;
    String score(GameTeam t) => hide ? '–' : (t.score ?? '');

    final status = switch (game.state) {
      GameState.upcoming => DateFormat.jm().format(game.kickoff.toLocal()),
      GameState.live => game.statusText,
      GameState.finished =>
        game.statusText.isEmpty ? 'Final' : game.statusText,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: TvActivatable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        builder: (tap) => Material(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: tap,
            onLongPress: hide
                ? () => ref
                    .read(sportsRevealedProvider.notifier)
                    .update((s) => {...s, game.id})
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium!.copyWith(
                        color: live
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: live ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: game.hasTeams
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _TeamLine(
                                  team: game.away!,
                                  score: showScores ? score(game.away!) : null),
                              const SizedBox(height: 6),
                              _TeamLine(
                                  team: game.home!,
                                  score: showScores ? score(game.home!) : null),
                            ],
                          )
                        : Text(game.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamLine extends StatelessWidget {
  const _TeamLine({required this.team, this.score});

  final GameTeam team;
  final String? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: team.logoUrl == null
              ? null
              : CachedNetworkImage(
                  imageUrl: team.logoUrl!,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge),
        ),
        if (score != null)
          Text(score!,
              style: theme.textTheme.titleMedium!
                  .copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
