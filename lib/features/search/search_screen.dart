import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:open_iptv/shared/widgets/parental_pin_dialog.dart';

bool _genreIsAdult(String? genre) =>
    (genre ?? 'Other').split(',').map((g) => g.trim()).any(isAdultCategory);

bool _genreIsLocked(
        String? genre, AppPreferences prefs, Set<String> sessionUnlocked) =>
    (genre ?? 'Other')
        .split(',')
        .map((g) => g.trim())
        .any((g) => isCategoryLocked(g, prefs, sessionUnlocked));

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _searchQueryProvider = StateProvider<String>((ref) => '');

final _searchResultsProvider =
    FutureProvider<SearchResults>((ref) async {
  final query = ref.watch(_searchQueryProvider);
  if (query.trim().length < SearchService.minQueryLength) {
    return SearchResults.empty;
  }

  final db = ref.watch(appDatabaseProvider);
  final epg = ref.watch(epgServiceProvider);

  final channels = await db.getAllChannels();
  final movies = await db.getAllMovies();
  final series = await db.getAllSeries();
  final currentProgrammes = await epg.searchCurrentProgrammes(query);

  final results = const SearchService().search(
    query: query,
    channels: channels,
    currentProgrammes: currentProgrammes,
    movies: movies,
    series: series,
  );

  // Kid profiles never see adult content in search results at all —
  // mirrors the auto-hide behavior on the Live/Movies/Series browse screens.
  final profile = await ref.watch(activeProfileProvider.future);
  if (profile?.isKidsProfile != true) return results;

  return SearchResults(
    channels: results.channels
        .where((c) => !isAdultCategory(c.groupTitle ?? 'Uncategorized'))
        .toList(),
    movies: results.movies.where((m) => !_genreIsAdult(m.genre)).toList(),
    series: results.series.where((s) => !_genreIsAdult(s.genre)).toList(),
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

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
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
          autofocus: true,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Search channels, movies, series…',
            border: InputBorder.none,
            filled: false,
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  )
                : null,
          ),
          style: theme.textTheme.bodyLarge,
        ),
      ),
      body: query.length < SearchService.minQueryLength
          ? const _SearchPrompt()
          : resultsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                child: Text('Search is unavailable right now.'),
              ),
              data: (results) {
                if (results.isEmpty) {
                  return _EmptyResults(query: query);
                }
                return _ResultsList(results: results);
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Results list
// ---------------------------------------------------------------------------

class _ResultsList extends ConsumerWidget {
  const _ResultsList({required this.results});

  final SearchResults results;

  Future<void> _gate(
    BuildContext context,
    WidgetRef ref,
    String label,
    VoidCallback proceed,
  ) async {
    final pin = await showParentalPinEntry(
        context, 'Enter admin PIN to unlock "$label"');
    if (pin == null) return;
    if (!await ref.read(profileServiceProvider).verifyAnyAdminPin(pin)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
      }
      return;
    }
    proceed();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final sessionUnlocked = ref.watch(parentalSessionUnlockedProvider);

    bool channelLocked(Channel c) => prefs != null &&
        isCategoryLocked(
            c.groupTitle ?? 'Uncategorized', prefs, sessionUnlocked);
    bool genreLocked(String? genre) =>
        prefs != null && _genreIsLocked(genre, prefs, sessionUnlocked);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (results.channels.isNotEmpty)
          _ResultGroup<Channel>(
            title: 'Live Channels',
            items: results.channels,
            icon: Icons.live_tv,
            labelOf: (c) => c.name,
            subtitleOf: (_) => null,
            isLockedOf: channelLocked,
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

class _ResultGroup<T> extends StatelessWidget {
  const _ResultGroup({
    required this.title,
    required this.items,
    required this.icon,
    required this.labelOf,
    required this.subtitleOf,
    required this.onTap,
    this.isLockedOf,
  });

  final String title;
  final List<T> items;
  final IconData icon;
  final String Function(T) labelOf;
  final String? Function(T) subtitleOf;
  final void Function(T) onTap;
  final bool Function(T)? isLockedOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Icon(icon, size: 16,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall ??
                    theme.textTheme.bodyMedium!
                        .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        ...items.map(
          (item) => ListTile(
            title: Text(
              labelOf(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: subtitleOf(item) != null
                ? Text(
                    subtitleOf(item)!,
                    style: theme.textTheme.bodySmall,
                  )
                : null,
            trailing: (isLockedOf?.call(item) ?? false)
                ? Icon(Icons.lock_outline,
                    size: 16, color: theme.colorScheme.onSurfaceVariant)
                : null,
            onTap: () => onTap(item),
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
