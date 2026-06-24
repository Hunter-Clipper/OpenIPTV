import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/series.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/widgets/app_logo.dart';
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
  // null = genre grid; non-null = filtered series grid
  String? _selectedGenre;

  Future<void> _refresh() async {
    try {
      final sources = await ref.read(allSourcesProvider.future);
      for (final s in sources) {
        await ref.read(sourceManagerProvider).refreshSeries(s);
      }
    } finally {
      ref.invalidate(_allSeriesProvider);
      await ref.read(_allSeriesProvider.future);
    }
  }

  List<String> _buildGenres(List<Series> all) {
    final genres = all
        .map((s) => s.genre ?? 'Other')
        .expand((g) => g.split(',').map((s) => s.trim()))
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return genres;
  }

  List<Series> _filteredSeries(List<Series> all, String genre) {
    if (genre == 'All') return all;
    return all.where((s) {
      final g = s.genre ?? '';
      return g.toLowerCase().contains(genre.toLowerCase());
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
        leading: _selectedGenre != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedGenre = null),
              )
            : const AppLogo(),
        title: Text(_selectedGenre != null
            ? (_selectedGenre == 'All' ? 'All Series' : _selectedGenre!)
            : 'Series'),
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
          final favIdSet = (profile?.favoriteSeriesIds ?? []).toSet();
          final favorites =
              all.where((s) => favIdSet.contains(s.id)).toList();

          if (_selectedGenre == null) {
            // Genre selection screen with Favorites row on top
            final genres = _buildGenres(all);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  // Favorites
                  if (favorites.isNotEmpty) ...[
                    _SectionHeader(title: 'Favorites'),
                    SliverToBoxAdapter(
                      child: _HorizontalPosterRow(
                        items: favorites,
                        profileId: profile?.id,
                      ),
                    ),
                  ],

                  // Genre tiles
                  _SectionHeader(title: 'Browse by Genre'),
                  SliverToBoxAdapter(
                    child: _GenreTileList(
                      genres: genres.isEmpty ? ['All'] : genres,
                      seriesCounts: {
                        if (genres.isEmpty) 'All': all.length,
                        for (final g in genres)
                          g: all
                              .where((s) => (s.genre ?? '').contains(g))
                              .length,
                      },
                      onTap: (g) => setState(() => _selectedGenre = g),
                      profileId: profile?.id,
                      onHideGenre: profile?.id == null
                          ? null
                          : (g) async {
                              HapticFeedback.mediumImpact();
                              final hide =
                                  await showModalBottomSheet<bool>(
                                context: context,
                                builder: (_) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(
                                            Icons.visibility_off_outlined),
                                        title:
                                            const Text('Hide Genre'),
                                        subtitle: Text(g,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                        onTap: () =>
                                            Navigator.of(context)
                                                .pop(true),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                              if (hide == true) {
                                await ref
                                    .read(profileServiceProvider)
                                    .hideCategory(profile!.id, g);
                                ref.invalidate(activeProfileProvider);
                              }
                            },
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                ],
              ),
            );
          }

          // Filtered series grid
          final filtered = _filteredSeries(all, _selectedGenre!);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              key: ValueKey(_selectedGenre),
              slivers: [
                if (filtered.isEmpty)
                  const SliverFillRemaining(child: _EmptyView())
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
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
// Genre tile list
// ---------------------------------------------------------------------------

class _GenreTileList extends StatelessWidget {
  const _GenreTileList({
    required this.genres,
    required this.seriesCounts,
    required this.onTap,
    this.profileId,
    this.onHideGenre,
  });

  final List<String> genres;
  final Map<String, int> seriesCounts;
  final void Function(String) onTap;
  final String? profileId;
  final void Function(String)? onHideGenre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: genres.map((g) {
        return ListTile(
          leading: Icon(
            g == 'All'
                ? Icons.video_library_outlined
                : Icons.category_outlined,
            color: theme.colorScheme.primary,
          ),
          title: Text(g),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (seriesCounts[g] ?? 0).toString(),
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () => onTap(g),
          onLongPress: g == 'All' || onHideGenre == null
              ? null
              : () => onHideGenre!(g),
        );
      }).toList(),
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
// Horizontal favorites row
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

  void _showOptions(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    final isFav = ref
            .read(activeProfileProvider)
            .valueOrNull
            ?.favoriteSeriesIds
            .contains(series.id) ??
        false;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isFav ? Icons.star_border : Icons.star),
              title: Text(isFav ? 'Remove from Favorites' : 'Add to Favorites'),
              onTap: () {
                Navigator.pop(context);
                if (profileId != null) {
                  ref
                      .read(profileServiceProvider)
                      .toggleFavoriteSeries(profileId!, series.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isFav = ref.watch(activeProfileProvider.select(
        (a) => a.valueOrNull?.favoriteSeriesIds.contains(series.id) ?? false));

    return GestureDetector(
      onTap: () => context.push('/series/${series.id}'),
      onLongPress: profileId == null ? null : () => _showOptions(context, ref),
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
          const Text("Couldn't load series. Try again."),
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
