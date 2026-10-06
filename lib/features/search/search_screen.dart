import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/search_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/widgets/detail_header.dart';
import 'package:open_iptv/shared/widgets/empty_state_view.dart';
import 'package:open_iptv/shared/widgets/error_state_view.dart';
import 'package:open_iptv/shared/widgets/media_rail.dart';
import 'package:open_iptv/shared/widgets/parental_pin_dialog.dart';
import 'package:open_iptv/shared/widgets/skeleton.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/shared/widgets/tv_nav_rail_focus.dart';
import 'package:open_iptv/ui/platform_helper.dart';


// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _searchQueryProvider = StateProvider<String>((ref) => '');

final _searchResultsProvider =
    FutureProvider.autoDispose<SearchResults>((ref) async {
  final query = ref.watch(_searchQueryProvider);
  if (query.trim().length < SearchService.minQueryLength) {
    return SearchResults.empty;
  }

  // Search follows the active playlist, like the browse tabs; null means
  // "All playlists". The matching happens in the database isolate — never
  // load the whole catalog here: with large playlists that froze the UI
  // (and the remote) for ~10 s on TVs (#38).
  final search = SearchService(ref.watch(appDatabaseProvider));
  final epg = ref.watch(epgServiceProvider);
  final sourceId = ref.watch(activeSourceIdProvider);
  final airing = await epg.searchCurrentProgrammes(query);
  final results = await search.search(
    query: query,
    currentProgrammes: airing,
    sourceId: sourceId,
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
  List<String> _recent = const [];

  static const _maxRecent = 8;

  // On phones the field's node; on TV the node of the field's outline
  // (TvTextFieldGate), which is where the remote stops — OK on it opens the
  // keyboard. Focusing the field itself on TV popped Google TV's keyboard
  // over the screen every time the tab opened (#38).
  final FocusNode _searchFocusNode = FocusNode();
  // Wraps everything below the search bar; Down from the field goes to its
  // first item (the first result or recent-search chip) — directional
  // search picked whichever card sat geometrically closest instead.
  final FocusNode _belowBarNode =
      FocusNode(canRequestFocus: false, skipTraversal: true);

  @override
  void initState() {
    super.initState();
    // The query outlives this screen (switching tabs rebuilds it); show it
    // in the box, or the old results sit under an empty field.
    _controller.text = ref.read(_searchQueryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && PlatformHelper.isTV(context)) {
        _searchFocusNode.requestFocus();
      }
    });
    ref.read(appPreferencesProvider.future).then((prefs) {
      if (mounted) setState(() => _recent = prefs.recentSearches);
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _belowBarNode.dispose();
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // From the outline (TV) Left always goes to the menu; inside the field
    // it moves the caret unless there's nothing to move through.
    if (key == LogicalKeyboardKey.arrowLeft &&
        (_controller.text.isEmpty || _searchFocusNode.hasPrimaryFocus &&
            PlatformHelper.isTV(context))) {
      TvNavRailFocus.maybeOf(context)?.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final first = _belowBarNode.traversalDescendants.firstOrNull;
      if (first != null) {
        first.requestFocus();
        return KeyEventResult.handled;
      }
      final moved = FocusManager.instance.primaryFocus
              ?.focusInDirection(TraversalDirection.down) ??
          false;
      return moved
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(_searchQueryProvider.notifier).state = value.trim();
    });
    setState(() {}); // clear button
  }

  void _search(String query) {
    _debounce?.cancel();
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    ref.read(_searchQueryProvider.notifier).state = query;
    setState(() {});
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(_searchQueryProvider.notifier).state = '';
    setState(() {});
  }

  /// Keeps the current query in the recent list once it led somewhere.
  Future<void> _remember() async {
    final q = ref.read(_searchQueryProvider).trim();
    if (q.length < SearchService.minQueryLength) return;
    final next = [
      q,
      ..._recent.where((r) => r.toLowerCase() != q.toLowerCase()),
    ].take(_maxRecent).toList();
    setState(() => _recent = next);
    await (await ref.read(appPreferencesProvider.future))
        .setRecentSearches(next);
  }

  Future<void> _clearRecent() async {
    setState(() => _recent = const []);
    await (await ref.read(appPreferencesProvider.future))
        .setRecentSearches(const []);
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_searchQueryProvider);
    final resultsAsync = ref.watch(_searchResultsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Sees the arrows before the field's own caret handling, from
            // the field or (TV) its outline.
            Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _handleKey,
              child: _SearchBar(
                controller: _controller,
                focusNode: _searchFocusNode,
                onChanged: _onChanged,
                onSubmitted: (q) {
                  _search(q);
                  // Keyboard closed: give the remote back to the outline.
                  if (PlatformHelper.isTV(context)) {
                    _searchFocusNode.requestFocus();
                  }
                },
                onClear: _clearSearch,
              ),
            ),
            Expanded(
              child: Focus(
                focusNode: _belowBarNode,
                child: query.length < SearchService.minQueryLength
                    ? _SearchHome(
                        recent: _recent,
                        onPick: _search,
                        onClear: _clearRecent,
                      )
                    : resultsAsync.when(
                        loading: () =>
                            const SkeletonList(itemCount: 6, leadingSize: 0),
                        error: (_, __) => ErrorStateView(
                          message: "Couldn't load search results. Try again.",
                          onRetry: () => ref.invalidate(_searchResultsProvider),
                        ),
                        data: (results) => results.isEmpty
                            ? EmptyStateView(
                                icon: Icons.search_off_rounded,
                                title: 'No results for "$query"',
                                message:
                                    'Check the spelling, or try a channel, a '
                                    'movie or a show name.',
                              )
                            : _ResultsList(
                                results: results,
                                onOpen: _remember,
                              ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search bar
// ---------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TvTextFieldGate(
        focusNode: focusNode,
        borderRadius: BorderRadius.circular(28),
        builder: (context, fieldNode) => TextField(
        controller: controller,
        focusNode: fieldNode,
        // On TV the screen focuses the outline instead (no keyboard).
        autofocus: !PlatformHelper.isTV(context),
        onChanged: onChanged,
        onSubmitted: (v) => onSubmitted(v.trim()),
        textInputAction: TextInputAction.search,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search channels, movies and series',
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHigh,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          border: pill,
          enabledBorder: pill,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide:
                BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 4),
            child: Icon(Icons.search_rounded,
                color: theme.colorScheme.onSurfaceVariant),
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : TvFocusable(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.close_rounded),
                  ),
                ),
        ),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Before a search: recent searches, or a short welcome
// ---------------------------------------------------------------------------

class _SearchHome extends StatelessWidget {
  const _SearchHome({
    required this.recent,
    required this.onPick,
    required this.onClear,
  });

  final List<String> recent;
  final ValueChanged<String> onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const welcome = EmptyStateView(
      icon: Icons.search_rounded,
      title: 'Find something to watch',
      message: "Search Live TV channels, movies, series — and what's on "
          'right now.',
    );
    if (recent.isEmpty) return welcome;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Text('Recent searches',
              style: theme.textTheme.titleMedium!
                  .copyWith(fontWeight: FontWeight.w600, fontSize: 17)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in recent)
                TvActivatable(
                  onTap: () => onPick(q),
                  builder: (onTap) => ActionChip(
                    avatar: const Icon(Icons.history_rounded, size: 18),
                    label: Text(q),
                    shape: const StadiumBorder(),
                    onPressed: onTap,
                  ),
                ),
            ],
          ),
        ),
        // Below the chips (not beside the title) so Down from the search
        // bar lands on the first chip, not on Clear.
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TvActivatable(
              onTap: onClear,
              builder: (onTap) => TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Clear recent searches'),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        welcome,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Results: a row per kind, like the home screens
// ---------------------------------------------------------------------------

class _ResultsList extends ConsumerWidget {
  const _ResultsList({required this.results, required this.onOpen});

  final SearchResults results;
  // Called when a result is opened, to remember the query.
  final VoidCallback onOpen;

  Future<void> _open(BuildContext context, WidgetRef ref, String label,
      bool locked, VoidCallback proceed) async {
    if (locked &&
        !await promptAdminPin(
            context, ref, 'Enter admin PIN to unlock "$label"')) {
      return;
    }
    onOpen();
    proceed();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final sessionUnlocked = ref.watch(parentalSessionUnlockedProvider);

    bool channelLocked(Channel c) =>
        prefs != null &&
        c.categories
            .any((cat) => isCategoryLocked(cat, prefs, sessionUnlocked));
    bool genreLocked(String? genre) =>
        prefs != null && isGenreLocked(genre, prefs, sessionUnlocked);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (results.channels.isNotEmpty)
          MediaRail(
            title: 'Live TV',
            count: results.channels.length,
            shape: RailShape.logo,
            fallbackIcon: Icons.tv_rounded,
            items: [
              for (final c in results.channels)
                RailItem(
                  title: context.displayName(c.name),
                  subtitle: results.nowPlaying[c.id] ?? 'Live',
                  highlightSubtitle: results.nowPlaying.containsKey(c.id),
                  imageUrl: c.logoUrl,
                  locked: channelLocked(c),
                  onTap: () => _open(
                    context,
                    ref,
                    context.displayName(c.name),
                    channelLocked(c),
                    () => context.push('/player', extra: {
                      'streamUrl': c.streamUrl,
                      'title': c.name,
                      'contentType': 'live',
                      'contentId': c.id,
                    }),
                  ),
                ),
            ],
          ),
        if (results.movies.isNotEmpty)
          MediaRail(
            title: 'Movies',
            count: results.movies.length,
            items: [
              for (final m in results.movies)
                RailItem(
                  title: context.displayName(m.title),
                  imageUrl: genreLocked(m.genre) ? null : m.posterUrl,
                  locked: genreLocked(m.genre),
                  heroTag: posterHeroTag('search', m.id),
                  onTap: () => _open(
                    context,
                    ref,
                    context.displayName(m.title),
                    genreLocked(m.genre),
                    () => context.push('/movies/${m.id}',
                        extra: posterHeroTag('search', m.id)),
                  ),
                ),
            ],
          ),
        if (results.series.isNotEmpty)
          MediaRail(
            title: 'Series',
            count: results.series.length,
            fallbackIcon: Icons.video_library_outlined,
            items: [
              for (final s in results.series)
                RailItem(
                  title: context.displayName(s.title),
                  imageUrl: genreLocked(s.genre) ? null : s.posterUrl,
                  locked: genreLocked(s.genre),
                  heroTag: posterHeroTag('search', s.id),
                  onTap: () => _open(
                    context,
                    ref,
                    context.displayName(s.title),
                    genreLocked(s.genre),
                    () => context.push('/series/${s.id}',
                        extra: posterHeroTag('search', s.id)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
