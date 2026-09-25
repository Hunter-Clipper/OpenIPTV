import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/models/series.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/search_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/widgets/error_state_view.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';
import 'package:open_iptv/shared/widgets/parental_pin_dialog.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/shared/widgets/tv_nav_rail_focus.dart';

// Read by _ShellState (app.dart) when the native Back-button channel fires
// while sitting on the Search tab, to decide whether Back should refocus the
// nav rail (search field was focused) or leave the tab entirely. A plain
// ValueNotifier rather than Riverpod/InheritedWidget plumbing since it only
// ever needs a one-off synchronous read at the exact moment Back fires, not
// a rebuild-driving subscription.
final ValueNotifier<bool> searchFieldFocused = ValueNotifier<bool>(false);

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _searchQueryProvider = StateProvider<String>((ref) => '');

/// The full searchable catalog, loaded once while the Search tab is open
/// (autoDispose) rather than on every debounced keystroke — reloading tens
/// of thousands of rows per query made results take several seconds.
final _searchCatalogProvider = FutureProvider.autoDispose<
    ({List<Channel> channels, List<Movie> movies, List<Series> series})>(
  (ref) async {
    final db = ref.watch(appDatabaseProvider);
    final (channels, movies, series) = await (
      db.getAllChannels(),
      db.getAllMovies(),
      db.getAllSeries(),
    ).wait;
    return (channels: channels, movies: movies, series: series);
  },
);

final _searchResultsProvider =
    FutureProvider.autoDispose<SearchResults>((ref) async {
  // Watched before the short-query early return so the catalog stays
  // loaded (and starts preloading as soon as the tab opens) between queries.
  final catalogFuture = ref.watch(_searchCatalogProvider.future);
  final query = ref.watch(_searchQueryProvider);
  if (query.trim().length < SearchService.minQueryLength) {
    return SearchResults.empty;
  }

  final epg = ref.watch(epgServiceProvider);
  // Only what's airing right now changes between queries, so only the
  // programme search runs per query.
  final (catalog, currentProgrammes) = await (
    catalogFuture,
    epg.searchCurrentProgrammes(query),
  ).wait;

  final results = const SearchService().search(
    query: query,
    channels: catalog.channels,
    currentProgrammes: currentProgrammes,
    movies: catalog.movies,
    series: catalog.series,
  );

  // Kid profiles never see adult content in search results at all —
  // mirrors the auto-hide behavior on the Live/Movies/Series browse screens.
  final profile = await ref.watch(activeProfileProvider.future);
  if (profile?.isKidsProfile != true) return results;

  return SearchResults(
    channels: results.channels
        .where((c) => !c.categories.any(isAdultCategory))
        .toList(),
    movies: results.movies.where((m) => !isAdultGenre(m.genre)).toList(),
    series: results.series.where((s) => !isAdultGenre(s.genre)).toList(),
    nowPlaying: results.nowPlaying,
  );
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  // A plain TextField swallows arrow keys for its own (single-line, no-op)
  // caret movement, so it never bubbles up to Flutter's directional focus
  // system — arrow-left here would otherwise never reach the nav rail, and
  // arrow-down would never reach the results list below. Handling them
  // directly on this exact FocusNode (rather than an ancestor) intercepts
  // them before EditableText's own key handling gets a chance.
  late final FocusNode _searchFocusNode = FocusNode(onKeyEvent: _handleKey);
  final FocusNode _firstResultFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleFocusChange);
    _searchFocusNode.dispose();
    _firstResultFocusNode.dispose();
    _controller.dispose();
    _debounce?.cancel();
    searchFieldFocused.value = false;
    super.dispose();
  }

  void _handleFocusChange() {
    searchFieldFocused.value = _searchFocusNode.hasFocus;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft && _controller.text.isEmpty) {
      TvNavRailFocus.maybeOf(context)?.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && _controller.text.isNotEmpty) {
      final results = ref.read(_searchResultsProvider).valueOrNull;
      if (results != null && !results.isEmpty) {
        _firstResultFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(_searchQueryProvider.notifier).state = value.trim();
    });
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(_searchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_searchQueryProvider);
    final resultsAsync = ref.watch(_searchResultsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          focusNode: _searchFocusNode,
          autofocus: true,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Search channels, movies, series…',
            border: InputBorder.none,
            filled: false,
            suffixIcon: query.isNotEmpty
                ? TvFocusable(
                    onTap: _clearSearch,
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.clear),
                    ),
                  )
                : null,
          ),
          style: theme.textTheme.bodyLarge,
        ),
      ),
      body: query.length < SearchService.minQueryLength
          ? const _SearchPrompt()
          : resultsAsync.when(
              loading: () => const LoadingView(),
              error: (_, __) => ErrorStateView(
                message: "Couldn't load search results. Try again.",
                onRetry: () => ref.invalidate(_searchResultsProvider),
              ),
              data: (results) {
                if (results.isEmpty) {
                  return _EmptyResults(query: query);
                }
                return _ResultsList(
                  results: results,
                  firstItemFocusNode: _firstResultFocusNode,
                );
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results list
// ---------------------------------------------------------------------------

class _ResultsList extends ConsumerWidget {
  const _ResultsList({required this.results, required this.firstItemFocusNode});

  final SearchResults results;
  // Attached to the very first result tile across all groups (whichever
  // group is non-empty first), so arrow-down from the search field has a
  // fixed, reliable landing spot regardless of which groups are present.
  final FocusNode firstItemFocusNode;

  Future<void> _gate(
    BuildContext context,
    WidgetRef ref,
    String label,
    VoidCallback proceed,
  ) async {
    if (await promptAdminPin(
        context, ref, 'Enter admin PIN to unlock "$label"')) {
      proceed();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final sessionUnlocked = ref.watch(parentalSessionUnlockedProvider);

    bool channelLocked(Channel c) => prefs != null &&
        c.categories
            .any((cat) => isCategoryLocked(cat, prefs, sessionUnlocked));
    bool genreLocked(String? genre) =>
        prefs != null && isGenreLocked(genre, prefs, sessionUnlocked);

    final firstGroupIsChannels = results.channels.isNotEmpty;
    final firstGroupIsMovies = !firstGroupIsChannels && results.movies.isNotEmpty;
    final firstGroupIsSeries = !firstGroupIsChannels &&
        !firstGroupIsMovies &&
        results.series.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (results.channels.isNotEmpty)
          _ResultGroup<Channel>(
            title: 'Live TV',
            items: results.channels,
            icon: Icons.live_tv,
            labelOf: (c) => c.name,
            subtitleOf: (c) {
              final now = results.nowPlaying[c.id];
              return now == null ? null : 'Now: $now';
            },
            isLockedOf: channelLocked,
            firstItemFocusNode: firstGroupIsChannels ? firstItemFocusNode : null,
            onTap: (c) {
              void proceed() => context.push('/player', extra: {
                    'streamUrl': c.streamUrl,
                    'title': c.name,
                    'contentType': 'live',
                    'contentId': c.id,
                  });
              if (channelLocked(c)) {
                _gate(context, ref, c.name, proceed);
              } else {
                proceed();
              }
            },
          ),
        if (results.movies.isNotEmpty)
          _ResultGroup<Movie>(
            title: 'Movies',
            items: results.movies,
            icon: Icons.movie_outlined,
            labelOf: (m) => m.title,
            subtitleOf: (m) => m.year,
            isLockedOf: (m) => genreLocked(m.genre),
            firstItemFocusNode: firstGroupIsMovies ? firstItemFocusNode : null,
            onTap: (m) {
              void proceed() => context.push('/movies/${m.id}');
              if (genreLocked(m.genre)) {
                _gate(context, ref, m.title, proceed);
              } else {
                proceed();
              }
            },
          ),
        if (results.series.isNotEmpty)
          _ResultGroup<Series>(
            title: 'Series',
            items: results.series,
            icon: Icons.video_library_outlined,
            labelOf: (s) => s.title,
            subtitleOf: (s) => s.year,
            isLockedOf: (s) => genreLocked(s.genre),
            firstItemFocusNode: firstGroupIsSeries ? firstItemFocusNode : null,
            onTap: (s) {
              void proceed() => context.push('/series/${s.id}');
              if (genreLocked(s.genre)) {
                _gate(context, ref, s.title, proceed);
              } else {
                proceed();
              }
            },
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Generic result group
// ---------------------------------------------------------------------------

class _ResultGroup<T> extends StatefulWidget {
  const _ResultGroup({
    required this.title,
    required this.items,
    required this.icon,
    required this.labelOf,
    required this.subtitleOf,
    required this.onTap,
    this.isLockedOf,
    this.firstItemFocusNode,
  });

  final String title;
  final List<T> items;
  final IconData icon;
  final String Function(T) labelOf;
  final String? Function(T) subtitleOf;
  final void Function(T) onTap;
  final bool Function(T)? isLockedOf;
  // Non-null only when this is the first group rendered across all result
  // types — see _ResultsList.
  final FocusNode? firstItemFocusNode;

  @override
  State<_ResultGroup<T>> createState() => _ResultGroupState<T>();
}

class _ResultGroupState<T> extends State<_ResultGroup<T>> {
  // A broad query can match dozens of channels; showing them all would push
  // the Movies/Series groups (often what the user wanted) far off screen.
  static const _collapsedCount = 5;
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant _ResultGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New query → start collapsed again.
    if (!identical(oldWidget.items, widget.items)) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = widget.items;
    final shown = _expanded || items.length <= _collapsedCount
        ? items
        : items.take(_collapsedCount).toList();
    final hidden = items.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Icon(widget.icon, size: 16,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: theme.textTheme.titleSmall ??
                    theme.textTheme.bodyMedium!
                        .copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              Text(
                '${items.length}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        ...shown.asMap().entries.map((entry) {
          final item = entry.value;
          final subtitle = widget.subtitleOf(item);
          return TvActivatable(
            focusNode: entry.key == 0 ? widget.firstItemFocusNode : null,
            onTap: () => widget.onTap(item),
            builder: (onTap) => ListTile(
              title: Text(
                widget.labelOf(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: subtitle != null
                  ? Text(subtitle, style: theme.textTheme.bodySmall)
                  : null,
              trailing: (widget.isLockedOf?.call(item) ?? false)
                  ? Icon(Icons.lock_outline,
                      size: 16, color: theme.colorScheme.onSurfaceVariant)
                  : null,
              onTap: onTap,
            ),
          );
        }),
        if (hidden > 0)
          TvActivatable(
            onTap: () => setState(() => _expanded = true),
            builder: (onTap) => ListTile(
              leading: Icon(Icons.expand_more,
                  color: theme.colorScheme.primary),
              title: Text(
                'Show all ${items.length}',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
              onTap: onTap,
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / prompt states
// ---------------------------------------------------------------------------

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Type at least 2 characters to search.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "$query".',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different spelling or check your sources are loaded.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
