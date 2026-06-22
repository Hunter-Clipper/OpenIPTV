import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/series.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/ui/platform_helper.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _allSeriesProvider = FutureProvider<List<Series>>((ref) {
  return ref.watch(appDatabaseProvider).getAllSeries();
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SeriesScreen extends ConsumerStatefulWidget {
  const SeriesScreen({super.key});

  @override
  ConsumerState<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends ConsumerState<SeriesScreen> {
  String _selectedGenre = 'All';

  Future<void> _refresh() async {
    ref.invalidate(_allSeriesProvider);
    await ref.read(_allSeriesProvider.future);
  }

  List<String> _buildGenres(List<Series> all) {
    final genres = all
        .map((s) => s.genre ?? 'Other')
        .expand((g) => g.split(',').map((s) => s.trim()))
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...genres];
  }

  List<Series> _filteredSeries(List<Series> all) {
    if (_selectedGenre == 'All') return all;
    return all.where((s) {
      final genre = s.genre ?? '';
      return genre.toLowerCase().contains(_selectedGenre.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(_allSeriesProvider);
    final profileAsync = ref.watch(activeProfileProvider);
    final profile = profileAsync.valueOrNull;
    final columns = PlatformHelper.posterColumns(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Series'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: allAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorView(onRetry: _refresh),
        data: (all) {
          final genres = _buildGenres(all);
          final filtered = _filteredSeries(all);
          final favIds = profile?.favoriteSeriesIds ?? [];
          final favourites =
              all.where((s) => favIds.contains(s.id)).toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              slivers: [
                // Genre chips
                SliverToBoxAdapter(
                  child: _GenreFilterRow(
                    genres: genres,
                    selected: _selectedGenre,
                    onSelected: (g) => setState(() => _selectedGenre = g),
                  ),
                ),

                // Favourites row
                if (favourites.isNotEmpty) ...[
                  _SectionHeader(title: 'Favourites'),
                  SliverToBoxAdapter(
                    child: _HorizontalPosterRow(
                      items: favourites,
                      profileId: profile?.id,
                    ),
                  ),
                ],

                // All series grid
                _SectionHeader(
                    title: _selectedGenre == 'All'
                        ? 'All Series'
                        : _selectedGenre),
                filtered.isEmpty
                    ? const SliverFillRemaining(child: _EmptyView())
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        sliver: SliverGrid(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _PosterCard(
                              series: filtered[i],
                              profileId: profile?.id,
                            ),
                            childCount: filtered.length,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: AppTheme.posterAspectRatio,
                          ),
                        ),
                      ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Genre filter row
// ---------------------------------------------------------------------------

class _GenreFilterRow extends StatelessWidget {
  const _GenreFilterRow({
    required this.genres,
    required this.selected,
    required this.onSelected,
  });

  final List<String> genres;
  final String selected;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: genres.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ChoiceChip(
          label: Text(genres[i]),
          selected: genres[i] == selected,
          onSelected: (_) => onSelected(genres[i]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal favourites row
// ---------------------------------------------------------------------------

class _HorizontalPosterRow extends ConsumerWidget {
  const _HorizontalPosterRow({
    required this.items,
    required this.profileId,
  });

  final List<Series> items;
  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = items[i];
          return GestureDetector(
            onTap: () => context.push('/series/${s.id}'),
            child: SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppTheme.cardRadius),
                      child: _PosterImage(posterUrl: s.posterUrl),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Poster card (grid)
// ---------------------------------------------------------------------------

class _PosterCard extends ConsumerWidget {
  const _PosterCard({required this.series, required this.profileId});

  final Series series;
  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isFav = ref
            .watch(activeProfileProvider)
            .valueOrNull
            ?.favoriteSeriesIds
            .contains(series.id) ??
        false;

    return GestureDetector(
      onTap: () => context.push('/series/${series.id}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: _PosterImage(posterUrl: series.posterUrl),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: profileId == null
                  ? null
                  : () => ref
                      .read(profileServiceProvider)
                      .toggleFavoriteSeries(profileId!, series.id),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isFav ? Icons.star : Icons.star_border,
                  size: 16,
                  color: isFav
                      ? theme.colorScheme.primary
                      : Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.posterUrl});

  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    if (posterUrl == null || posterUrl!.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
            child: Icon(Icons.video_library_outlined, size: 40)),
      );
    }
    return CachedNetworkImage(
      imageUrl: posterUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      errorWidget: (_, __, ___) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
            child: Icon(Icons.video_library_outlined, size: 40)),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 16),
          const Text('Couldn't load series. Try again.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try Again')),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No series found.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}
