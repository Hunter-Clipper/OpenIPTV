import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _allChannelsProvider = FutureProvider<List<Channel>>((ref) {
  return ref.watch(appDatabaseProvider).getAllChannels();
});

final _categoriesProvider = Provider<List<String>>((ref) {
  final channels = ref.watch(_allChannelsProvider).valueOrNull ?? [];
  final cats = channels
      .map((c) => c.groupTitle ?? 'Uncategorised')
      .toSet()
      .toList()
    ..sort();
  return ['All', 'Favourites', ...cats];
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
  String _selectedCategory = 'All';

  Future<void> _refresh() async {
    ref.invalidate(_allChannelsProvider);
    await ref.read(_allChannelsProvider.future);
  }

  List<Channel> _filteredChannels(List<Channel> all, String? profileId) {
    List<Channel> result;
    if (_selectedCategory == 'All') {
      result = List.of(all);
    } else if (_selectedCategory == 'Favourites') {
      result = all.where((c) => c.isFavorite).toList();
    } else {
      result = all
          .where((c) => (c.groupTitle ?? 'Uncategorised') == _selectedCategory)
          .toList();
    }

    // Always put favourites at the top.
    result.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(_allChannelsProvider);
    final categories = ref.watch(_categoriesProvider);
    final profileAsync = ref.watch(activeProfileProvider);
    final profileId = profileAsync.valueOrNull?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live TV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: channelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(onRetry: _refresh),
        data: (all) {
          final channels = _filteredChannels(all, profileId);
          return Column(
            children: [
              _CategoryTabBar(
                categories: categories,
                selected: _selectedCategory,
                onSelected: (cat) => setState(() => _selectedCategory = cat),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: channels.isEmpty
                      ? const _EmptyView()
                      : ListView.builder(
                          itemCount: channels.length,
                          itemBuilder: (context, i) {
                            return _ChannelRow(
                              channel: channels[i],
                              profileId: profileId,
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category tab bar
// ---------------------------------------------------------------------------

class _CategoryTabBar extends StatelessWidget {
  const _CategoryTabBar({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<String> categories;
  final String selected;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isSelected = cat == selected;
          return ChoiceChip(
            label: Text(cat),
            selected: isSelected,
            onSelected: (_) => onSelected(cat),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Channel row
// ---------------------------------------------------------------------------

class _ChannelRow extends ConsumerWidget {
  const _ChannelRow({required this.channel, required this.profileId});

  final Channel channel;
  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _ChannelLogo(url: channel.logoUrl),
      title: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: _NowNextText(channelId: channel.id),
      trailing: IconButton(
        icon: Icon(
          channel.isFavorite ? Icons.star : Icons.star_border,
          color: channel.isFavorite
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        onPressed: profileId == null
            ? null
            : () => ref
                .read(profileServiceProvider)
                .toggleFavoriteChannel(profileId!, channel.id),
      ),
      onTap: () => context.push('/player', extra: {
        'streamUrl': channel.streamUrl,
        'title': channel.name,
        'contentType': 'live',
        'contentId': channel.id,
      }),
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
// Now/next programme subtitle
// ---------------------------------------------------------------------------

class _NowNextText extends ConsumerWidget {
  const _NowNextText({required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prog = ref.watch(_nowProgrammeProvider(channelId)).valueOrNull;
    if (prog == null) return const SizedBox.shrink();
    return Text(
      prog.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall,
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
