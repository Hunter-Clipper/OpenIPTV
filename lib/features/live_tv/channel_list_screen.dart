import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/providers/channel_providers.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/live_tv/tv_guide_screen.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/utils/genre_icons.dart';
import 'package:open_iptv/shared/widgets/app_logo.dart';
import 'package:open_iptv/shared/widgets/browse_app_bar_actions.dart';
import 'package:open_iptv/shared/widgets/category_tile.dart';
import 'package:open_iptv/shared/widgets/empty_state_view.dart';
import 'package:open_iptv/shared/widgets/error_state_view.dart';
import 'package:open_iptv/shared/widgets/media_rail.dart';
import 'package:open_iptv/shared/widgets/parental_pin_dialog.dart';
import 'package:open_iptv/shared/widgets/skeleton.dart';
import 'package:open_iptv/shared/widgets/star_button.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _recentChannelsProvider = StreamProvider<List<Channel>>((ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  final db = ref.watch(appDatabaseProvider);
  if (profileId == null) return const Stream.empty();
  return db.watchRecentChannels(profileId,
      sourceId: ref.watch(activeSourceIdProvider));
});

// Caches EPG programme per channel so scrolling doesn't re-fire DB queries.
final _nowProgrammeProvider =
    FutureProvider.autoDispose.family<Programme?, String>((ref, channelId) {
  return ref.read(epgServiceProvider).getCurrentProgramme(channelId);
});

// What's on now and next, per channel, for the category list rows.
final _nowNextProvider = FutureProvider.autoDispose
    .family<(Programme?, Programme?), String>((ref, channelId) async {
  final epg = ref.read(epgServiceProvider);
  final now = await epg.getCurrentProgramme(channelId);
  final next = await epg.getNextProgramme(channelId);
  return (now, next);
});

/// Re-fetches channels for every source, then reloads [allChannelsProvider].
/// Shared pull-to-refresh handler for the category list and category screens.
Future<void> _refreshAllChannels(WidgetRef ref) async {
  try {
    final sources = await ref.read(allSourcesProvider.future);
    for (final s in sources) {
      await ref.read(sourceManagerProvider).refreshChannels(s);
    }
  } finally {
    ref.invalidate(allChannelsProvider);
    await ref.read(allChannelsProvider.future);
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ChannelListScreen extends ConsumerStatefulWidget {
  const ChannelListScreen({super.key});

  @override
  ConsumerState<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends ConsumerState<ChannelListScreen> {
  List<String> _buildCategories(
      List<Channel> channels, Set<String> hidden, String sort) {
    // Preserve first-appearance order (channels are already in provider/sortOrder
    // sequence from the DB), then either keep that or sort A-Z.
    final seen = <String>{};
    final cats = <String>[];
    for (final c in channels) {
      for (final cat in c.categories) {
        if (!hidden.contains(cat) && seen.add(cat)) cats.add(cat);
      }
    }
    if (sort == 'az') cats.sort();
    return cats;
  }

  void _showRemoveRecentSheet(Channel ch) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              autofocus: true,
              leading: Icon(Icons.remove_circle_outline,
                  color: Theme.of(sheetContext).colorScheme.error),
              title: const Text('Remove from Recently Watched'),
              onTap: () async {
                Navigator.pop(sheetContext);
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

  Future<void> _tapCategory(String cat) async {
    if (!await ensureCategoryUnlocked(context, ref, cat)) return;
    if (mounted) {
      unawaited(context.push('/live/category/${Uri.encodeComponent(cat)}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(allChannelsProvider);
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
        actions: const [
          SortToggleAction(),
          SettingsAction(),
        ],
      ),
      body: channelsAsync.when(
        loading: () => const SkeletonList(leadingSize: 28),
        error: (e, _) => ErrorStateView(
            message: "Couldn't load channels. Check your internet connection.",
            onRetry: () => ref.invalidate(allChannelsProvider)),
        data: (all) {
          final cats = _buildCategories(all, hiddenCats, sort)
              .where((c) => !isKid || !isAdultCategory(c))
              .toList();
          final favorites = all
              .where((c) => favIds.contains(c.id))
              .where((c) => !isKid || !c.categories.any(isAdultCategory))
              .toList();
          final recent =
              ref.watch(_recentChannelsProvider).valueOrNull ?? [];
          final catCounts = <String, int>{};
          for (final c in all) {
            for (final cat in c.categories) {
              catCounts[cat] = (catCounts[cat] ?? 0) + 1;
            }
          }
          return RefreshIndicator(
            onRefresh: () => _refreshAllChannels(ref),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Labelled entry point rather than an icon-only app-bar
                // button — the old grid icon looked like the list/grid view
                // switch used elsewhere.
                if (kTvGuideEnabled) const _TvGuideTile(),
                if (favorites.isNotEmpty)
                  _ChannelRail(
                    title: 'Favorites',
                    // The guide card normally takes the first D-pad focus.
                    autofocusFirst: !kTvGuideEnabled,
                    channels: favorites.take(20).toList(),
                    onSeeAll: () => context.push(
                        '/live/category/${Uri.encodeComponent('Favorites')}'),
                    onLongPress: profileId == null
                        ? null
                        : (ch) => _showChannelOptions(
                            context, ref, ch, profileId, true),
                  ),
                if (recent.isNotEmpty)
                  _ChannelRail(
                    title: 'Recently Watched',
                    autofocusFirst: !kTvGuideEnabled && favorites.isEmpty,
                    channels: recent,
                    onLongPress: (ch) => _showRemoveRecentSheet(ch),
                  ),
                if (favorites.isNotEmpty || recent.isNotEmpty)
                  const RailHeader(title: 'Categories'),
                if (cats.isEmpty)
                  CategoryTile(
                    label: 'All',
                    autofocus: !kTvGuideEnabled &&
                        favorites.isEmpty &&
                        recent.isEmpty,
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
                    autofocus: !kTvGuideEnabled &&
                        favorites.isEmpty &&
                        recent.isEmpty &&
                        cat == cats.first,
                    count: count,
                    icon: genreIcon(cat, fallback: Icons.folder_outlined),
                    isLocked: locked,
                    onTap: () => _tapCategory(cat),
                    onLongPress: profileId == null
                        ? null
                        : () async {
                            unawaited(HapticFeedback.mediumImpact());
                            final hide = await showModalBottomSheet<bool>(
                              context: context,
                              useRootNavigator: true,
                              builder: (sheetContext) =>
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
          .where((c) => c.categories.contains(widget.category))
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
    final channelsAsync = ref.watch(allChannelsProvider);
    final profileAsync = ref.watch(activeProfileProvider);
    final profile = profileAsync.valueOrNull;
    final profileId = profile?.id;
    final favIds = (profile?.favoriteChannelIds ?? []).toSet();
    final sort = ref.watch(contentSortProvider);
    final viewMode = ref.watch(viewModeLiveProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.displayName(widget.category)),
        actions: [
          ViewModeToggleAction(
            provider: viewModeLiveProvider,
            setMode: setViewModeLive,
          ),
          const SortToggleAction(),
          const SettingsAction(),
        ],
      ),
      body: channelsAsync.when(
        loading: () => const SkeletonList(leadingSize: 44),
        error: (e, _) => ErrorStateView(
            message: "Couldn't load channels. Check your internet connection.",
            onRetry: () => ref.invalidate(allChannelsProvider)),
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
            final cols = switch (PlatformHelper.getLayout(context)) {
              AppLayout.phone => 2,
              AppLayout.tablet => 3,
              AppLayout.tv => 4,
            };
            return RefreshIndicator(
              onRefresh: () => _refreshAllChannels(ref),
              child: LayoutBuilder(builder: (context, c) {
                const pad = 16.0, gap = 12.0;
                final w = (c.maxWidth - pad * 2 - gap * (cols - 1)) / cols;
                return GridView.builder(
                  key: ValueKey('${widget.category}_grid'),
                  padding: const EdgeInsets.fromLTRB(pad, 12, pad, 24),
                  itemCount: channels.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: gap,
                    mainAxisExtent: w * 9 / 16 + 50,
                  ),
                  itemBuilder: (context, i) {
                    final ch = channels[i];
                    final fav = favIds.contains(ch.id);
                    return _LiveChannelCard(
                      channel: ch,
                      width: w,
                      autofocus: i == 0,
                      onLongPress: profileId == null
                          ? null
                          : () => _showChannelOptions(
                              context, ref, ch, profileId, fav),
                      favoriteButton: StarButton(
                        isFavorite: fav,
                        onTap: profileId == null
                            ? null
                            : () async {
                                await ref
                                    .read(profileServiceProvider)
                                    .toggleFavoriteChannel(profileId, ch.id);
                                ref.invalidate(activeProfileProvider);
                              },
                      ),
                    );
                  },
                );
              }),
            );
          }
          return RefreshIndicator(
            onRefresh: () => _refreshAllChannels(ref),
            child: ListView.builder(
              key: ValueKey('${widget.category}_list'),
              itemCount: channels.length,
              itemBuilder: (context, i) {
                final ch = channels[i];
                return _ChannelRow(
                  channel: ch,
                  profileId: profileId,
                  isFavorite: favIds.contains(ch.id),
                  autofocus: i == 0,
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
// Channel tile actions (shared by grid card and list row)
// ---------------------------------------------------------------------------

void _playChannel(BuildContext context, Channel channel) {
  context.push('/player', extra: {
    'streamUrl': channel.streamUrl,
    'title': channel.name,
    'contentType': 'live',
    'contentId': channel.id,
  });
}

void _showChannelOptions(BuildContext context, WidgetRef ref, Channel channel,
    String profileId, bool isFavorite) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    builder: (sheetContext) => _ChannelOptionsSheet(
      isFavorite: isFavorite,
      onToggle: () async {
        await ref
            .read(profileServiceProvider)
            .toggleFavoriteChannel(profileId, channel.id);
        ref.invalidate(activeProfileProvider);
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Channel grid card
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Channel row — logo tile, name, what's on now (time + progress) and next
// ---------------------------------------------------------------------------

class _ChannelRow extends ConsumerWidget {
  const _ChannelRow({
    required this.channel,
    required this.profileId,
    required this.isFavorite,
    this.autofocus = false,
  });

  final Channel channel;
  final String? profileId;
  final bool isFavorite;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final guide = ref.watch(_nowNextProvider(channel.id)).valueOrNull;
    final now = guide?.$1;
    final next = guide?.$2;
    void onTap() => _playChannel(context, channel);
    final onLongPress = profileId == null
        ? null
        : () => _showChannelOptions(
            context, ref, channel, profileId!, isFavorite);

    return TvFocusable(
      wrapsGesture: false,
      autofocus: autofocus,
      ensureVisibleOnFocus: true,
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      onLongPress: onLongPress,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
            children: [
              _LogoTile(
                url: channel.logoUrl,
                width: PlatformHelper.isTV(context) ? 120 : 96,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            context.displayName(channel.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        if (channel.hasCatchup) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Catch-up available',
                            child: Icon(Icons.history_rounded,
                                size: 15, color: muted),
                          ),
                        ],
                      ],
                    ),
                    if (now != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        now.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium!.copyWith(
                            color: theme.colorScheme.primary, fontSize: 13.5),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Text(
                            '${_hm(context, now.start)} – ${_hm(context, now.end)}',
                            style: theme.textTheme.bodySmall!
                                .copyWith(color: muted, fontSize: 11.5),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: now
                                    .progressAt(DateTime.now())
                                    .clamp(0.0, 1.0),
                                minHeight: 3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (next != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Next  ${_hm(context, next.start)}  ${next.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall!
                            .copyWith(color: muted, fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: isFavorite ? theme.colorScheme.primary : muted,
                ),
                tooltip:
                    isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
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
        ),
      ),
    );
  }
}

/// A channel logo on a soft 16:10 tile — logos come in every shape and
/// colour, and a uniform tile keeps the list tidy.
class _LogoTile extends StatelessWidget {
  const _LogoTile({required this.url, required this.width});

  final String? url;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = Icon(Icons.tv_rounded,
        size: width * 0.3, color: theme.colorScheme.onSurfaceVariant);
    return Container(
      width: width,
      height: width * 10 / 16,
      padding: EdgeInsets.all(width * 0.1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: logoTileColors,
        ),
      ),
      child: url == null || url!.isEmpty
          ? icon
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.contain,
              memCacheWidth: (width * 2).toInt(),
              errorWidget: (_, __, ___) => icon,
            ),
    );
  }
}

String _hm(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(t),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

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
            autofocus: true,
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
// Channel rails (Favorites / Recently Watched) — landscape cards with the
// programme on now
// ---------------------------------------------------------------------------

class _ChannelRail extends StatefulWidget {
  const _ChannelRail({
    required this.title,
    required this.channels,
    this.onSeeAll,
    this.onLongPress,
    this.autofocusFirst = false,
  });

  final String title;
  final List<Channel> channels;
  final VoidCallback? onSeeAll;
  final void Function(Channel)? onLongPress;
  final bool autofocusFirst;

  @override
  State<_ChannelRail> createState() => _ChannelRailState();
}

class _ChannelRailState extends State<_ChannelRail> {
  // Landing spot for "D-pad focus just entered this row from elsewhere" (see
  // the wrapping Focus's onFocusChange below) — always the first card,
  // regardless of which card the directional search would have geometrically
  // picked otherwise.
  final FocusNode _firstItemFocusNode = FocusNode();

  @override
  void dispose() {
    _firstItemFocusNode.dispose();
    super.dispose();
  }

  // A FocusNode's `hasFocus` is true if it OR ANY DESCENDANT has focus, so
  // this fires exactly once when focus arrives in the row from outside (the
  // false->true edge) — not on every move between cards within the row.
  void _handleRowFocusChange(bool hasFocus) {
    if (hasFocus && widget.channels.isNotEmpty) {
      _firstItemFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = PlatformHelper.isTV(context) ? 220.0 : 176.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RailHeader(title: widget.title, onSeeAll: widget.onSeeAll),
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: _handleRowFocusChange,
          child: SizedBox(
            height: width * 9 / 16 + 56,
            child: TvRowFocus(
              child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              clipBehavior: Clip.none,
              itemCount: widget.channels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final ch = widget.channels[i];
                return _LiveChannelCard(
                  channel: ch,
                  width: width,
                  focusNode: i == 0 ? _firstItemFocusNode : null,
                  autofocus: widget.autofocusFirst && i == 0,
                  onLongPress: widget.onLongPress == null
                      ? null
                      : () => widget.onLongPress!(ch),
                );
              },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveChannelCard extends ConsumerStatefulWidget {
  const _LiveChannelCard({
    required this.channel,
    required this.width,
    this.focusNode,
    this.onLongPress,
    this.autofocus = false,
    this.favoriteButton,
  });

  final Channel channel;
  final double width;
  final FocusNode? focusNode;
  final VoidCallback? onLongPress;
  final bool autofocus;
  // Overlaid top-right (the grid's favorite star).
  final Widget? favoriteButton;

  @override
  ConsumerState<_LiveChannelCard> createState() => _LiveChannelCardState();
}

class _LiveChannelCardState extends ConsumerState<_LiveChannelCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ch = widget.channel;
    final prog = ref.watch(_nowProgrammeProvider(ch.id)).valueOrNull;
    final lit = _focused && PlatformHelper.isTV(context);
    final radius = BorderRadius.circular(12);
    final logo = ch.logoUrl;
    return TvFocusable(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      ensureVisibleOnFocus: true,
      showFocusRing: false,
      onFocusChange: (f) => setState(() => _focused = f),
      onTap: () => _playChannel(context, ch),
      onLongPress: widget.onLongPress,
      child: SizedBox(
        width: widget.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedScale(
              scale: lit ? 1.06 : 1.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: widget.width,
                height: widget.width * 9 / 16,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: logoTileColors,
                  ),
                  border: Border.all(
                    color: lit ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: lit
                          ? theme.colorScheme.primary.withValues(alpha: 0.35)
                          : Colors.black.withValues(alpha: 0.3),
                      blurRadius: lit ? 18 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                        child: logo != null && logo.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: logo,
                                fit: BoxFit.contain,
                                memCacheWidth: 300,
                                errorWidget: (_, __, ___) => Icon(Icons.tv,
                                    size: 36,
                                    color: theme.colorScheme.onSurfaceVariant),
                              )
                            : Icon(Icons.tv,
                                size: 36,
                                color: theme.colorScheme.onSurfaceVariant),
                      ),
                      if (widget.favoriteButton != null)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: widget.favoriteButton!,
                        ),
                      if (prog != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: prog
                                .progressAt(DateTime.now())
                                .clamp(0.0, 1.0),
                            minHeight: 3,
                            backgroundColor: Colors.black38,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.displayName(ch.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium!
                  .copyWith(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            Text(
              prog?.title ?? 'Live',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall!.copyWith(
                fontSize: 11.5,
                color: prog == null
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "TV Guide" entry at the top of Live TV: full-width, labelled and
/// explained, so it can't be mistaken for anything else.
class _TvGuideTile extends StatelessWidget {
  const _TvGuideTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: TvFocusable(
        autofocus: true,
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/live/guide'),
        child: Material(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push('/live/guide'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.view_timeline_outlined,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TV Guide',
                            style: theme.textTheme.titleMedium!
                                .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text("See what's on now and next",
                            style: theme.textTheme.bodySmall!.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
