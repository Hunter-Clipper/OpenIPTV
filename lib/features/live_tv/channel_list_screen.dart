import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/widgets/app_logo.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _allChannelsProvider = FutureProvider<List<Channel>>((ref) {
  return ref.watch(appDatabaseProvider).getAllChannels();
});

final _recentChannelsProvider = StreamProvider<List<Channel>>((ref) {
  return ref.watch(appDatabaseProvider).watchRecentChannels();
});

// Caches EPG programme per channel so scrolling doesn't re-fire DB queries.
final _nowProgrammeProvider =
    FutureProvider.autoDispose.family<Programme?, String>((ref, channelId) {
  return ref.read(epgServiceProvider).getCurrentProgramme(channelId);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ChannelListScreen extends ConsumerStatefulWidget {
  const ChannelListScreen({super.key});

  @override
  ConsumerState<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends ConsumerState<ChannelListScreen> {
  // null = showing category grid; non-null = showing channels in that category
  String? _selectedCategory;

  Future<void> _refreshChannels() async {
    try {
      final sources = await ref.read(allSourcesProvider.future);
      for (final s in sources) {
        await ref.read(sourceManagerProvider).refreshChannels(s);
      }
    } finally {
      ref.invalidate(_allChannelsProvider);
      await ref.read(_allChannelsProvider.future);
    }
  }

  List<Channel> _channelsForCategory(
      List<Channel> all, Set<String> favIds, String category, String sort) {
    List<Channel> result;
    if (category == 'All') {
      result = List.of(all);
    } else if (category == 'Favorites') {
      result = all.where((c) => favIds.contains(c.id)).toList();
    } else {
      result = all
          .where((c) => (c.groupTitle ?? 'Uncategorized') == category)
          .toList();
    }
    if (sort == 'az') {
      result.sort((a, b) => a.name.compareTo(b.name));
    } else {
      result.sort((a, b) {
        final aFav = favIds.contains(a.id);
        final bFav = favIds.contains(b.id);
        if (aFav && !bFav) return -1;
        if (!aFav && bFav) return 1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    }
    return result;
  }

  List<String> _buildCategories(
      List<Channel> channels, Set<String> hidden, String sort) {
    // Preserve first-appearance order (channels are already in provider/sortOrder
    // sequence from the DB), then either keep that or sort A-Z.
    final seen = <String>{};
    final cats = <String>[];
    for (final c in channels) {
      final cat = c.groupTitle ?? 'Uncategorized';
      if (!hidden.contains(cat) && seen.add(cat)) cats.add(cat);
    }
    if (sort == 'az') cats.sort();
    return cats;
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(_allChannelsProvider);
    final profileAsync = ref.watch(activeProfileProvider);
    final profile = profileAsync.valueOrNull;
    final profileId = profile?.id;
    final favIds = (profile?.favoriteChannelIds ?? []).toSet();
    final hiddenCats = (profile?.hiddenCategories ?? []).toSet();

    final sort = ref.watch(contentSortProvider);
    return Scaffold(
      appBar: AppBar(
        leading: _selectedCategory != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _selectedCategory = null),
              )
            : const AppLogo(),
        title: Text(_selectedCategory ?? 'Live TV'),
        actions: [
          IconButton(
            icon: Icon(sort == 'az'
                ? Icons.sort_by_alpha
                : Icons.sort),
            tooltip: sort == 'az' ? 'Sorted A–Z' : 'Provider order',
            onPressed: () async {
              final prefs = await ref.read(appPreferencesProvider.future);
              await setContentSort(
                  ref, sort == 'az' ? 'provider' : 'az', prefs);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: channelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(
            onRetry: () {
              ref.invalidate(_allChannelsProvider);
            }),
        data: (all) {
          if (_selectedCategory == null) {
            // Category grid
            final cats = _buildCategories(all, hiddenCats, sort);
            final favCount = favIds.length;
            final recent = ref.watch(_recentChannelsProvider).valueOrNull ?? [];
            return RefreshIndicator(
              onRefresh: _refreshChannels,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (recent.isNotEmpty) ...[
                    _SectionHeader(title: 'Recently Watched'),
                    _RecentChannelsRow(channels: recent),
                  ],
                  if (favCount > 0)
                    _CategoryTile(
                      label: 'Favorites',
                      count: favCount,
                      icon: Icons.star_outlined,
                      onTap: () =>
                          setState(() => _selectedCategory = 'Favorites'),
                    ),
                  // Show "All" only when no categories exist
                  if (cats.isEmpty)
                    _CategoryTile(
                      label: 'All',
                      count: all.length,
                      icon: Icons.live_tv_outlined,
                      onTap: () => setState(() => _selectedCategory = 'All'),
                    ),
                  ...cats.map((cat) {
                    final count = all
                        .where((c) =>
                            (c.groupTitle ?? 'Uncategorized') == cat)
                        .length;
                    return _CategoryTile(
                      label: cat,
                      count: count,
                      icon: Icons.folder_outlined,
                      onTap: () => setState(() => _selectedCategory = cat),
                      onLongPress: profileId == null
                          ? null
                          : () async {
                              // ListTile.enableFeedback already fires haptic on long-press.
                              final hide = await showModalBottomSheet<bool>(
                                context: context,
                                builder: (_) =>
                                    _CategoryOptionsSheet(label: cat),
                              );
                              if (hide == true && mounted) {
                                await ref
                                    .read(profileServiceProvider)
                                    .hideCategory(profileId, cat);
                                ref.invalidate(activeProfileProvider);
                              }
                            },
                    );
                  }),
                ],
              ),
            );
          }

          // Channel list for selected category
          final channels =
              _channelsForCategory(all, favIds, _selectedCategory!, sort);
          return RefreshIndicator(
            onRefresh: _refreshChannels,
            child: channels.isEmpty
                ? const _EmptyView()
                : ListView.builder(
                    key: ValueKey(_selectedCategory),
                    itemCount: channels.length,
                    itemBuilder: (context, i) {
                      final ch = channels[i];
                      return _ChannelRow(
                        channel: ch,
                        profileId: profileId,
                        isFavorite: favIds.contains(ch.id),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category tile
// ---------------------------------------------------------------------------

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.onTap,
    this.onLongPress,
  });

  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: theme.textTheme.bodySmall!.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

// ---------------------------------------------------------------------------
// Channel row
// ---------------------------------------------------------------------------

class _ChannelRow extends ConsumerWidget {
  const _ChannelRow({
    required this.channel,
    required this.profileId,
    required this.isFavorite,
  });

  final Channel channel;
  final String? profileId;
  final bool isFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _ChannelLogo(url: channel.logoUrl),
      title: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: _EpgSubtitle(channelId: channel.id),
      trailing: IconButton(
        icon: Icon(
          isFavorite ? Icons.star : Icons.star_border,
          color: isFavorite
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        onPressed: profileId == null
            ? null
            : () async {
                await ref
                    .read(profileServiceProvider)
                    .toggleFavoriteChannel(profileId!, channel.id);
                ref.invalidate(activeProfileProvider);
              },
      ),
      onTap: () => context.push('/player', extra: {
        'streamUrl': channel.streamUrl,
        'title': channel.name,
        'contentType': 'live',
        'contentId': channel.id,
      }),
      onLongPress: profileId == null
          ? null
          : () {
              // ListTile.enableFeedback already fires haptic on long-press.
              showModalBottomSheet<void>(
                context: context,
                builder: (_) => _ChannelOptionsSheet(
                  isFavorite: isFavorite,
                  onToggle: () async {
                    await ref
                        .read(profileServiceProvider)
                        .toggleFavoriteChannel(profileId!, channel.id);
                    ref.invalidate(activeProfileProvider);
                  },
                ),
              );
            },
    );
  }
}

// ---------------------------------------------------------------------------
// Channel logo
// ---------------------------------------------------------------------------

class _ChannelLogo extends StatelessWidget {
  const _ChannelLogo({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (url == null || url!.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.tv, color: theme.colorScheme.onSurfaceVariant),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url!,
        width: 48,
        height: 48,
        fit: BoxFit.contain,
        placeholder: (_, __) => Container(
          width: 48,
          height: 48,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        errorWidget: (_, __, ___) => Container(
          width: 48,
          height: 48,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(Icons.tv, color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EPG subtitle — programme title + thin progress bar
// ---------------------------------------------------------------------------

class _EpgSubtitle extends ConsumerWidget {
  const _EpgSubtitle({required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prog = ref.watch(_nowProgrammeProvider(channelId)).valueOrNull;
    if (prog == null) return const SizedBox.shrink();
    final progress = prog.progressAt(DateTime.now()).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          prog.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          minHeight: 2,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category long-press options sheet
// ---------------------------------------------------------------------------

class _CategoryOptionsSheet extends StatelessWidget {
  const _CategoryOptionsSheet({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('Hide Category'),
            subtitle: Text(label,
                style: Theme.of(context).textTheme.bodySmall),
            onTap: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Channel long-press options sheet
// ---------------------------------------------------------------------------

class _ChannelOptionsSheet extends StatelessWidget {
  const _ChannelOptionsSheet({
    required this.isFavorite,
    required this.onToggle,
  });

  final bool isFavorite;
  final Future<void> Function() onToggle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(isFavorite ? Icons.star_border : Icons.star),
            title: Text(
                isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
            onTap: () {
              Navigator.of(context).pop();
              onToggle();
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error and empty states
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.signal_wifi_connected_no_internet_4, size: 48),
            const SizedBox(height: 16),
            Text(
              "Couldn't load channels. Check your internet connection.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recently Watched row
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}

class _RecentChannelsRow extends ConsumerWidget {
  const _RecentChannelsRow({required this.channels});
  final List<Channel> channels;

  void _showRemoveSheet(BuildContext context, WidgetRef ref, Channel ch) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Remove from Recently Watched'),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(appDatabaseProvider)
                    .clearChannelLastWatched(ch.id);
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
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: channels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final ch = channels[i];
          return GestureDetector(
            onTap: () => context.push('/player', extra: {
              'streamUrl': ch.streamUrl,
              'title': ch.name,
              'contentType': 'live',
              'contentId': ch.id,
            }),
            onLongPress: () => _showRemoveSheet(context, ref, ch),
            child: SizedBox(
              width: 80,
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ch.logoUrl != null && ch.logoUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              ch.logoUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.tv),
                            ),
                          )
                        : const Icon(Icons.tv),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ch.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.live_tv_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              'No channels here yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
