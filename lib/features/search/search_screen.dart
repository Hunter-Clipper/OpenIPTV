import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/movie.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/models/series.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/search_service.dart';
import 'package:open_iptv/core/storage/database.dart';

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
  final programmes = await epg.searchProgrammes(query);

  return const SearchService().search(
    query: query,
    channels: channels,
    programmes: programmes,
    movies: movies,
    series: series,
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

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results});

  final SearchResults results;

  @override
  Widget build(BuildContext context) {
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
            onTap: (c) => context.push('/player', extra: {
              'streamUrl': c.streamUrl,
              'title': c.name,
              'contentType': 'live',
              'contentId': c.id,
            }),
          ),
        if (results.programmes.isNotEmpty)
          _ResultGroup<Programme>(
            title: 'On TV',
            items: results.programmes,
            icon: Icons.calendar_today_outlined,
            labelOf: (p) => p.title,
            subtitleOf: (p) =>
                '${_formatTime(p.start)} – ${_formatTime(p.end)}',
            onTap: (_) {}, // Programmes are info-only — no navigation
          ),
        if (results.movies.isNotEmpty)
          _ResultGroup<Movie>(
            title: 'Movies',
            items: results.movies,
            icon: Icons.movie_outlined,
            labelOf: (m) => m.title,
            subtitleOf: (m) => m.year,
            onTap: (m) => context.push('/movies/${m.id}'),
          ),
        if (results.series.isNotEmpty)
          _ResultGroup<Series>(
            title: 'Series',
            items: results.series,
            icon: Icons.video_library_outlined,
            labelOf: (s) => s.title,
            subtitleOf: (s) => s.year,
            onTap: (s) => context.push('/series/${s.id}'),
          ),
      ],
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
  });

  final String title;
  final List<T> items;
  final IconData icon;
  final String Function(T) labelOf;
  final String? Function(T) subtitleOf;
  final void Function(T) onTap;

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
