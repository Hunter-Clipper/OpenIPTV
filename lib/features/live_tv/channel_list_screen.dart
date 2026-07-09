import 'dart:async';

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
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/widgets/app_logo.dart';
import 'package:open_iptv/shared/widgets/category_tile.dart';
import 'package:open_iptv/shared/widgets/empty_state_view.dart';
import 'package:open_iptv/shared/widgets/error_state_view.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';
import 'package:open_iptv/shared/widgets/parental_pin_dialog.dart';
import 'package:open_iptv/shared/widgets/section_header.dart';
import 'package:open_iptv/shared/widgets/star_button.dart';
import 'package:open_iptv/ui/platform_helper.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _allChannelsProvider = StreamProvider<List<Channel>>((ref) {
  final activeSourceId = ref.watch(activeSourceIdProvider);
  final db = ref.watch(appDatabaseProvider);
  final profileId = ref.watch(activeProfileProvider).valueOrNull?.id;
  if (activeSourceId != null) {
    return db.watchChannelsForSource(activeSourceId, profileId: profileId);
  }
  return db.watchAllChannels(profileId: profileId);
});

final _recentChannelsProvider = StreamProvider<List<Channel>>((ref) {
  final profileId = ref.watch(activeProfileProvider).valueOrNull?.id;
  final db = ref.watch(appDatabaseProvider);
  if (profileId == null) return const Stream.empty();
  return db.watchRecentChannels(profileId);
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

  Future<void> _tapCategory(String cat) async {
    final prefs = ref.read(appPreferencesProvider).valueOrNull;
    final sessionUnlocked = ref.read(parentalSessionUnlockedProvider);
    if (prefs != null && isCategoryLocked(cat, prefs, sessionUnlocked)) {
      final pin = await showParentalPinEntry(
          context, 'Enter admin PIN to unlock "$cat"');
      if (!mounted || pin == null) return;
      if (!await ref.read(profileServiceProvider).verifyAnyAdminPin(pin)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect PIN')));
        return;
      }
      ref.read(parentalSessionUnlockedProvider.notifier).state = {
        ...ref.read(parentalSessionUnlockedProvider),
        cat,
      };
    }
    if (mounted) {
      unawaited(context.push('/live/category/${Uri.encodeComponent(cat)}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(_allChannelsProvider);
    final profileAsync = ref.watch(activeProfileProvider);
    final profile = profileAsync.valueOrNull;
    final profileId = profile?.id;
    final favIds = (profile?.favoriteChannelIds ?? []).toSet();
    final hiddenCats = (profile?.hiddenCategories ?? []).toSet();
    final isKid = profile?.isKidsProfile ?? false;

    final sort = ref.watch(contentSortProvider);
    final parentalPrefs = ref.watch(appPreferencesProvider).valueOrNull;
    final sessionUnlocked = ref.watch(parentalSessionUnlockedProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppLogo(),
        title: const Text('Live TV'),
        actions: [
          IconButton(
            icon: Icon(sort == 'az' ? Icons.sort_by_alpha : Icons.sort),
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
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(
            message: "Couldn't load channels. Check your internet connection.",
            onRetry: () => ref.invalidate(_allChannelsProvider)),
        data: (all) {
          final cats = _buildCategories(all, hiddenCats, sort)
              .where((c) => !isKid || !isAdultCategory(c))
              .toList();
          final favCount = favIds.length;
          final recent =
              ref.watch(_recentChannelsProvider).valueOrNull ?? [];
          final catCounts = <String, int>{};
          for (final c in all) {
            final cat = c.groupTitle ?? 'Uncategorized';
            catCounts[cat] = (catCounts[cat] ?? 0) + 1;
          }
          return RefreshIndicator(
            onRefresh: _refreshChannels,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (recent.isNotEmpty) ...[
                  const SectionHeader('Recently Watched'),
                  _RecentChannelsRow(channels: recent),
                ],
                if (favCount > 0)
                  CategoryTile(
                    label: 'Favorites',
                    count: favCount,
                    icon: Icons.star_outlined,
                    onTap: () => context.push(
                        '/live/category/${Uri.encodeComponent('Favorites')}'),
                  ),
                if (cats.isEmpty)
                  CategoryTile(
                    label: 'All',
                    count: all.length,
                    icon: Icons.live_tv_outlined,
                    onTap: () => context.push(
                        '/live/category/${Uri.encodeComponent('All')}'),
                  ),
                ...cats.map((cat) {
                  final count = catCounts[cat] ?? 0;
                  final locked = parentalPrefs != null &&
                      isCategoryLocked(cat, parentalPrefs, sessionUnlocked);
                  return CategoryTile(
                    label: cat,
                    count: count,
                    icon: Icons.folder_outlined,
                    isLocked: locked,
                    onTap: () => _tapCategory(cat),
                    onLongPress: profileId == null
                        ? null
                        : () async {
                            unawaited(HapticFeedback.mediumImpact());
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
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live category screen (pushed as a route — back pops naturally)
// ---------------------------------------------------------------------------

class LiveCategoryScreen extends ConsumerStatefulWidget {
  const LiveCategoryScreen({super.key, required this.category});
  final String category;

  @override
  ConsumerState<LiveCategoryScreen> createState() =>
      _LiveCategoryScreenState();
}

class _LiveCategoryScreenState extends ConsumerState<LiveCategoryScreen> {
  Future<void> _refresh() async {
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

  static Future<void> _refreshStatic() async {}

  List<Channel> _channelsForCategory(
      List<Channel> all, Set<String> favIds, String sort) {
    List<Channel> result;
    if (widget.category == 'All') {
      result = List.of(all);
    } else if (widget.category == 'Favorites') {
      result = all.where((c) => favIds.contains(c.id)).toList();
    } else {
      result = all
          .where(
              (c) => (c.groupTitle ?? 'Uncategorized') == widget.category)
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

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(_allChannelsProvider);
    final profileAsync = ref.watch(activeProfileProvider);
    final profile = profileAsync.valueOrNull;
    final profileId = profile?.id;
    final favIds = (profile?.favoriteChannelIds ?? []).toSet();
    final sort = ref.watch(contentSortProvider);
    final viewMode = ref.watch(viewModeLiveProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        actions: [
          IconButton(
            icon:
                Icon(viewMode == 'grid' ? Icons.view_list : Icons.grid_view),
            tooltip: viewMode == 'grid'
                ? 'Switch to list view'
                : 'Switch to grid view',
            onPressed: () async {
              final prefs = await ref.read(appPreferencesProvider.future);
              await setViewModeLive(
                  ref, viewMode == 'grid' ? 'list' : 'grid', prefs);
            },
          ),
          IconButton(
            icon: Icon(sort == 'az' ? Icons.sort_by_alpha : Icons.sort),
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
        loading: () => const LoadingView(),
        error: (e, _) => ErrorStateView(
            message: "Couldn't load channels. Check your internet connection.",
            onRetry: () => ref.invalidate(_allChannelsProvider)),
        data: (all) {
          final channels = _channelsForCategory(all, favIds, sort);
          if (channels.isEmpty) {
            return const RefreshIndicator(
              onRefresh: _refreshStatic,
              child: EmptyStateView(
                icon: Icons.live_tv_outlined,
                message: 'No channels here yet.',
              ),
            );
          }
          if (viewMode == 'grid') {
            final cols = PlatformHelper.posterColumns(context);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: GridView.builder(
                key: ValueKey('${widget.category}_grid'),
                padding: const EdgeInsets.all(12),
                itemCount: channels.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, i) {
                  final ch = channels[i];
                  return _ChannelGridCard(
                    channel: ch,
                    profileId: profileId,
                    isFavorite: favIds.contains(ch.id),
                  );
                },
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              key: ValueKey('${widget.category}_list'),
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
// Channel grid card
// ---------------------------------------------------------------------------

class _ChannelGridCard extends ConsumerWidget {
  const _ChannelGridCard({
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
    return GestureDetector(
      onTap: () => context.push('/player', extra: {
        'streamUrl': channel.streamUrl,
        'title': channel.name,
        'contentType': 'live',
        'contentId': channel.id,
      }),
      onLongPress: profileId == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
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
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: _ChannelLogo(url: channel.logoUrl, size: 48),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    channel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall!
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  _EpgGridLine(channelId: channel.id),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: StarButton(
                isFavorite: isFavorite,
                onTap: profileId == null
                    ? null
                    : () async {
                        await ref
                            .read(profileServiceProvider)
                            .toggleFavoriteChannel(profileId!, channel.id);
                        ref.invalidate(activeProfileProvider);
                      },
              ),
            ),
            if (channel.hasCatchup)
              Positioned(
                top: 4,
                left: 4,
                child: Icon(Icons.replay_circle_filled_outlined,
                    size: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (channel.hasCatchup)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.replay_circle_filled_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
            onPressed: profileId == null
                ? null
                : () async {
                    await ref
                        .read(profileServiceProvider)
                        .toggleFavoriteChannel(profileId!, channel.id);
                    ref.invalidate(activeProfileProvider);
                  },
          ),
        ],
      ),
      onTap: () => context.push('/player', extra: {
        'streamUrl': channel.streamUrl,
        'title': channel.name,
        'contentType': 'live',
        'contentId': channel.id,
      }),
      enableFeedback: false,
      onLongPress: profileId == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
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
  const _ChannelLogo({required this.url, this.size = 48});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (url == null || url!.isEmpty) {
      return Container(
        width: size,
        height: size,
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
        width: size,
        height: size,
        fit: BoxFit.contain,
        memCacheWidth: size.toInt(),
        memCacheHeight: size.toInt(),
        placeholder: (_, __) => Container(
          width: size,
          height: size,
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
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
// EPG grid line — compact single-line programme + progress for grid cards
// ---------------------------------------------------------------------------

class _EpgGridLine extends ConsumerWidget {
  const _EpgGridLine({required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prog = ref.watch(_nowProgrammeProvider(channelId)).valueOrNull;
    if (prog == null) return const SizedBox.shrink();
    final progress = prog.progressAt(DateTime.now()).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          prog.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall!.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: theme.colorScheme.surface,
            valueColor:
                AlwaysStoppedAnimation(theme.colorScheme.primary),
          ),
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
// Recently Watched row
// ---------------------------------------------------------------------------

class _RecentChannelsRow extends ConsumerWidget {
  const _RecentChannelsRow({required this.channels});
  final List<Channel> channels;

  void _showRemoveSheet(BuildContext context, WidgetRef ref, Channel ch) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.remove_circle_outline,
                  color: Theme.of(sheetContext).colorScheme.error),
              title: const Text('Remove from Recently Watched'),
              onTap: () async {
                Navigator.pop(context);
                final profileId =
                    ref.read(activeProfileProvider).valueOrNull?.id;
                if (profileId == null) return;
                await ref
                    .read(appDatabaseProvider)
                    .clearChannelLastWatched(profileId, ch.id);
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
                            child: CachedNetworkImage(
                              imageUrl: ch.logoUrl!,
                              fit: BoxFit.contain,
                              memCacheWidth: 120,
                              memCacheHeight: 120,
                              errorWidget: (_, __, ___) =>
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
