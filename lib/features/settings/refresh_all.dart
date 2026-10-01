import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/source_manager.dart';
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
    // Refresh times (and any guide URL a playlist just reported).
    ref.invalidate(allSourcesProvider);
    state = RefreshAllState(
      last: scope,
      lastResults: results,
      finishedAt: DateTime.now(),
    );
  }
}

/// One plain-English line about a finished run.
String refreshSummary(RefreshScope scope, List<SourceRefreshResult> results) {
  final failed = results.where((r) => !r.succeeded).toList();
  if (failed.isEmpty) {
    return switch (scope) {
      RefreshScope.everything => 'Everything is up to date.',
      RefreshScope.playlists => 'All playlists are up to date.',
      RefreshScope.guides => 'All TV guides are up to date.',
    };
  }
  String problem(SourceRefreshResult r) {
    if (r.playlistError != null && r.epgError != null) {
      return "${r.nickname} couldn't be reached";
    }
    if (r.playlistError != null) {
      return "${r.nickname}'s channels couldn't be refreshed";
    }
    return "${r.nickname}'s TV guide isn't available";
  }

  final ok = results.length - failed.length;
  final lead = results.length == 1 ? '' : '$ok of ${results.length} updated. ';
  return '$lead${failed.map(problem).join('; ')}.';
}

/// The three Settings rows: Refresh Everything, Refresh Playlists, Refresh
/// TV Guides. While one runs, it shows progress and the others wait.
class RefreshAllTiles extends ConsumerWidget {
  const RefreshAllTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(refreshAllProvider);
    ref.listen(refreshAllProvider, (prev, next) {
      if (prev?.isRunning == true && !next.isRunning && next.last != null) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text(refreshSummary(next.last!, next.lastResults)),
        ));
      }
    });
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RefreshTile(
          scope: RefreshScope.everything,
          icon: Icons.sync_rounded,
          title: 'Refresh Everything',
          hint: 'Channels, movies, series and TV guides for every playlist',
          state: state,
        ),
        _RefreshTile(
          scope: RefreshScope.playlists,
          icon: Icons.playlist_add_check_rounded,
          title: 'Refresh Playlists',
          hint: 'Channels, movies and series only',
          state: state,
        ),
        _RefreshTile(
          scope: RefreshScope.guides,
          icon: Icons.event_note_outlined,
          title: 'Refresh TV Guides',
          hint: "What's on now and next, for every playlist",
          state: state,
        ),
      ],
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
    final runningThis = state.running == scope;
    final String subtitle;
    if (runningThis) {
      final what = scope == RefreshScope.guides ? "'s TV guide" : '';
      subtitle =
          'Updating ${state.current}$what… (${state.done + 1} of ${state.total})';
    } else if (state.last == scope && state.finishedAt != null) {
      final time = MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(state.finishedAt!),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
      subtitle = '$time · ${refreshSummary(scope, state.lastResults)}';
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
