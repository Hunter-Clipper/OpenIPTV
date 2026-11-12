import 'package:flutter/material.dart';
import 'package:open_iptv/shared/utils/format.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/widgets/info_tooltip.dart';
import 'package:open_iptv/core/services/guide_assignment_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/shared/utils/friendly_error.dart';
import 'package:open_iptv/shared/widgets/settings_group.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

/// What a one-tap "refresh all" covers.
enum RefreshScope {
  /// Every playlist's channels, movies and series, then its TV guide.
  everything,

  /// Channels, movies and series only.
  playlists,

  /// TV guides only.
  guides,
}

@immutable
class RefreshAllState {
  const RefreshAllState({
    this.running,
    this.done = 0,
    this.total = 0,
    this.current,
    this.currentIsExtraGuides = false,
    this.last,
    this.lastResults = const [],
    this.finishedAt,
  });

  /// The refresh in progress, or null when idle.
  final RefreshScope? running;
  final int done;
  final int total;

  /// Playlist being refreshed right now.
  final String? current;

  /// The run is on the extra guides step (no playlist name then).
  final bool currentIsExtraGuides;

  /// The most recent finished run, kept for the summary line.
  final RefreshScope? last;
  final List<SourceRefreshResult> lastResults;
  final DateTime? finishedAt;

  bool get isRunning => running != null;
}

/// Kept alive app-wide: a refresh keeps going (and reporting) if the user
/// leaves Settings while it runs.
final refreshAllProvider =
    NotifierProvider<RefreshAllNotifier, RefreshAllState>(
        RefreshAllNotifier.new);

class RefreshAllNotifier extends Notifier<RefreshAllState> {
  @override
  RefreshAllState build() => const RefreshAllState();

  /// Refreshes every playlist in turn. Playlists go one at a time (and,
  /// for [RefreshScope.everything], catalog before guide) so memory stays
  /// flat on low-end TVs. A failure is noted and the run carries on.
  Future<void> run(RefreshScope scope) async {
    if (state.isRunning) return;
    final sources = await ref.read(allSourcesProvider.future);
    if (sources.isEmpty) return;
    final manager = ref.read(sourceManagerProvider);
    final results = <SourceRefreshResult>[];
    for (final (i, source) in sources.indexed) {
      state = RefreshAllState(
        running: scope,
        done: i,
        total: sources.length,
        current: source.nickname,
        last: state.last,
        lastResults: state.lastResults,
        finishedAt: state.finishedAt,
      );
      results.add(await manager.refreshSourceParts(
        source,
        playlist: scope != RefreshScope.guides,
        guide: scope != RefreshScope.playlists,
      ));
    }
    // Extra guides and smart links, once every playlist's own guide is in.
    if (scope != RefreshScope.playlists) {
      state = RefreshAllState(
        running: scope,
        done: sources.length,
        total: sources.length,
        currentIsExtraGuides: true,
        last: state.last,
        lastResults: state.lastResults,
        finishedAt: state.finishedAt,
      );
      try {
        await ref.read(guideAssignmentProvider).sync();
      } catch (_) {}
      ref.read(guideRevisionProvider.notifier).state++;
    }
    // Refresh times (and any guide URL a playlist just reported).
    ref.invalidate(allSourcesProvider);
    state = RefreshAllState(
      last: scope,
      lastResults: results,
      finishedAt: DateTime.now(),
    );
  }
}

/// One plain-language line about a finished run.
String refreshSummary(AppLocalizations l10n, RefreshScope scope,
    List<SourceRefreshResult> results) {
  final failed = results.where((r) => !r.succeeded).toList();
  if (failed.isEmpty) {
    return switch (scope) {
      RefreshScope.everything => l10n.refreshAllSummaryEverything,
      RefreshScope.playlists => l10n.refreshAllSummaryPlaylists,
      RefreshScope.guides => l10n.refreshAllSummaryGuides,
    };
  }
  String problem(SourceRefreshResult r) {
    if (r.playlistError != null) {
      return l10n.refreshAllProblem(
          r.nickname, friendlySourceErrorMessage(r.playlistError!, l10n));
    }
    return l10n.refreshAllProblem(
        r.nickname, friendlyEpgErrorMessage(r.epgError!, l10n));
  }

  final problems = failed.map(problem).join('; ');
  if (results.length == 1) return l10n.refreshAllSummaryFailedOne(problems);
  return l10n.refreshAllSummaryFailedMany(
      results.length - failed.length, results.length, problems);
}

/// "Updating Home… (1 of 3)" for the refresh in progress.
String _runningLine(AppLocalizations l10n, RefreshAllState state) {
  final n = state.done + 1;
  if (state.currentIsExtraGuides) {
    return l10n.refreshAllUpdatingExtraGuides(n, state.total);
  }
  final name = state.current ?? '';
  return state.running == RefreshScope.guides
      ? l10n.refreshAllUpdatingGuide(name, n, state.total)
      : l10n.refreshAllUpdating(name, n, state.total);
}

/// The three Settings rows: Refresh Everything, Refresh Playlists, Refresh
/// TV Guides. While one runs, it shows progress and the others wait.
class RefreshAllTiles extends ConsumerWidget {
  const RefreshAllTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(refreshAllProvider);
    ref.listen(refreshAllProvider, (prev, next) {
      if (prev?.isRunning == true && !next.isRunning && next.last != null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(
              refreshSummary(l10n, next.last!, next.lastResults)),
        ));
      }
    });
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RefreshTile(
          scope: RefreshScope.everything,
          icon: Icons.sync_rounded,
          title: l10n.refreshAllEverythingTitle,
          hint: l10n.refreshAllEverythingHint,
          state: state,
        ),
        _RefreshTile(
          scope: RefreshScope.playlists,
          icon: Icons.playlist_add_check_rounded,
          title: l10n.refreshAllPlaylistsTitle,
          hint: l10n.refreshAllPlaylistsHint,
          state: state,
        ),
        _RefreshTile(
          scope: RefreshScope.guides,
          icon: Icons.event_note_outlined,
          title: l10n.refreshAllGuidesTitle,
          hint: l10n.refreshAllGuidesHint,
          state: state,
        ),
      ],
    );
  }
}

/// One row for every kind of refresh: shows what is running or what the last
/// run did, and asks which refresh to start when tapped.
class RefreshNowTile extends ConsumerWidget {
  const RefreshNowTile({super.key});

  static List<(RefreshScope, IconData, String, String)> _choices(
          AppLocalizations l10n) =>
      [
        (
          RefreshScope.everything,
          Icons.sync_rounded,
          l10n.refreshAllChoiceEverything,
          l10n.refreshAllEverythingHint
        ),
        (
          RefreshScope.playlists,
          Icons.playlist_add_check_rounded,
          l10n.refreshAllChoicePlaylists,
          l10n.refreshAllChoicePlaylistsHint
        ),
        (
          RefreshScope.guides,
          Icons.event_note_outlined,
          l10n.refreshAllChoiceGuides,
          l10n.refreshAllGuidesHint
        ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(refreshAllProvider);
    final theme = Theme.of(context);
    ref.listen(refreshAllProvider, (prev, next) {
      if (prev?.isRunning == true && !next.isRunning && next.last != null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(
              refreshSummary(l10n, next.last!, next.lastResults)),
        ));
      }
    });
    final String subtitle;
    if (state.isRunning) {
      subtitle = _runningLine(l10n, state);
    } else if (state.last != null && state.finishedAt != null) {
      final time = formatSystemTime(context, state.finishedAt!);
      subtitle = l10n.refreshAllLastRun(
          time, refreshSummary(l10n, state.last!, state.lastResults));
    } else {
      subtitle = l10n.refreshAllNowIdle;
    }
    // While one runs the row stays focusable (a no-op) so a TV remote keeps
    // its place.
    return InfoGutter(
      child: TvActivatable(
        onTap: state.isRunning
            ? () {}
            : () async {
                final scope = await showDialog<RefreshScope>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.refreshAllDialogTitle),
                    scrollable: true,
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, c) in _choices(l10n).indexed)
                          TvActivatable(
                            autofocus: i == 0,
                            onTap: () => Navigator.of(ctx).pop(c.$1),
                            builder: (tap) => ListTile(
                              leading: IconBadge(icon: c.$2),
                              title: Text(c.$3),
                              subtitle: Text(c.$4),
                              onTap: tap,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
                if (scope != null) {
                  await ref.read(refreshAllProvider.notifier).run(scope);
                }
              },
        builder: (onTap) => ListTile(
          leading: const IconBadge(icon: Icons.sync_rounded),
          title: Text(l10n.refreshAllNowTitle),
          subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
          trailing: state.isRunning
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : null,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _RefreshTile extends ConsumerWidget {
  const _RefreshTile({
    required this.scope,
    required this.icon,
    required this.title,
    required this.hint,
    required this.state,
  });

  final RefreshScope scope;
  final IconData icon;
  final String title;
  final String hint;
  final RefreshAllState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final runningThis = state.running == scope;
    final String subtitle;
    if (runningThis) {
      subtitle = _runningLine(l10n, state);
    } else if (state.last == scope && state.finishedAt != null) {
      final time = formatSystemTime(context, state.finishedAt!);
      subtitle = l10n.refreshAllLastRun(
          time, refreshSummary(l10n, scope, state.lastResults));
    } else {
      subtitle = hint;
    }
    // One refresh at a time: the others are disabled while one runs. The
    // running row stays focusable (a no-op) so a TV remote keeps its place
    // instead of focus jumping to a neighbouring row.
    final VoidCallback? action = runningThis
        ? () {}
        : state.isRunning
            ? null
            : () => ref.read(refreshAllProvider.notifier).run(scope);
    return TvActivatable(
      onTap: action,
      builder: (onTap) => ListTile(
        enabled: onTap != null,
        leading: IconBadge(icon: icon),
        title: Text(title),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: runningThis
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
