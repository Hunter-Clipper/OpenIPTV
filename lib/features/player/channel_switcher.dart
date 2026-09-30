import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/providers/channel_providers.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/epg_service.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/player/player_ui.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/utils/genre_icons.dart';
import 'package:open_iptv/shared/widgets/media_rail.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

const _favorites = '\u0000favorites';

/// Slides the channel list in from the right, over the video. Resolves with
/// the channel the user picked, or null if they closed it.
Future<Channel?> showChannelSwitcher(BuildContext context, String currentId) {
  return showGeneralDialog<Channel>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close channels',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => _ChannelSwitcher(currentId: currentId),
    transitionBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

final _nowOnProvider = FutureProvider.autoDispose
    .family<Programme?, String>((ref, channelId) =>
        ref.read(epgServiceProvider).getCurrentProgramme(channelId));

class _ChannelSwitcher extends ConsumerStatefulWidget {
  const _ChannelSwitcher({required this.currentId});

  final String currentId;

  @override
  ConsumerState<_ChannelSwitcher> createState() => _ChannelSwitcherState();
}

class _ChannelSwitcherState extends ConsumerState<_ChannelSwitcher> {
  String? _category;
  final _scroll = ScrollController();
  bool _scrolledToCurrent = false;

  static const _rowHeight = 72.0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Browsable categories, in the order Live TV shows them: favorites first,
  /// then first-appearance order (or A–Z), without hidden, locked, or — on
  /// a kids profile — adult ones.
  List<String> _categories(List<Channel> all) {
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final unlocked = ref.watch(parentalSessionUnlockedProvider);
    final hidden = (profile?.hiddenCategories ?? const []).toSet();
    final isKid = profile?.isKidsProfile ?? false;
    final seen = <String>{};
    final cats = <String>[];
    for (final c in all) {
      for (final cat in c.categories) {
        if (hidden.contains(cat) || !seen.add(cat)) continue;
        if (isKid && isAdultCategory(cat)) continue;
        if (prefs != null && isCategoryLocked(cat, prefs, unlocked)) continue;
        cats.add(cat);
      }
    }
    if (ref.watch(contentSortProvider) == 'az') cats.sort();
    final hasFavs = (profile?.favoriteChannelIds ?? const []).isNotEmpty;
    return [if (hasFavs) _favorites, ...cats];
  }

  List<Channel> _channelsIn(List<Channel> all, String cat) {
    final favIds =
        (ref.watch(activeProfileProvider).valueOrNull?.favoriteChannelIds ??
                const [])
            .toSet();
    final list = cat == _favorites
        ? all.where((c) => favIds.contains(c.id)).toList()
        : all.where((c) => c.categories.contains(cat)).toList();
    if (ref.watch(contentSortProvider) == 'az') {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return list;
  }

  String _label(BuildContext context, String cat) =>
      cat == _favorites ? 'Favorites' : context.displayName(cat);

  void _step(List<String> cats, int delta) {
    final i = cats.indexOf(_category!);
    setState(() {
      _category = cats[(i + delta + cats.length) % cats.length];
      _scrolledToCurrent = true; // new category: start at the top
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(allChannelsProvider).valueOrNull ?? const [];
    final cats = _categories(all);
    final current = all.where((c) => c.id == widget.currentId).firstOrNull;
    if (_category == null || !cats.contains(_category)) {
      _category = current?.categories
              .where(cats.contains)
              .firstOrNull ??
          (cats.isNotEmpty ? cats.first : null);
    }
    final cat = _category;
    final channels = cat == null ? const <Channel>[] : _channelsIn(all, cat);
    final currentIndex = channels.indexWhere((c) => c.id == widget.currentId);
    if (!_scrolledToCurrent && currentIndex > 2) {
      _scrolledToCurrent = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(((currentIndex - 2) * _rowHeight)
              .clamp(0, _scroll.position.maxScrollExtent));
        }
      });
    }
    final width = (MediaQuery.sizeOf(context).width * 0.42).clamp(320.0, 460.0);
    final m = PlayerMetrics.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: SafeArea(
            left: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Channels',
                            style: theme.textTheme.titleLarge!
                                .copyWith(fontWeight: FontWeight.w600)),
                      ),
                      PlayerButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close',
                        size: 44 * m.scale,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                if (cat != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      children: [
                        PlayerButton(
                          icon: Icons.chevron_left_rounded,
                          tooltip: 'Previous category',
                          size: 40 * m.scale,
                          onTap: () => _step(cats, -1),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  cat == _favorites
                                      ? Icons.star_rounded
                                      : genreIcon(cat,
                                          fallback: Icons.folder_outlined),
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _label(context, cat),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                                Text('${channels.length}',
                                    style: theme.textTheme.bodySmall!.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ),
                        PlayerButton(
                          icon: Icons.chevron_right_rounded,
                          tooltip: 'Next category',
                          size: 40 * m.scale,
                          onTap: () => _step(cats, 1),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemExtent: _rowHeight,
                    itemCount: channels.length,
                    itemBuilder: (context, i) {
                      final ch = channels[i];
                      return _ChannelRow(
                        channel: ch,
                        current: ch.id == widget.currentId,
                        autofocus: i == (currentIndex < 0 ? 0 : currentIndex),
                        onTap: () => Navigator.of(context).pop(ch),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelRow extends ConsumerWidget {
  const _ChannelRow({
    required this.channel,
    required this.current,
    required this.onTap,
    this.autofocus = false,
  });

  final Channel channel;
  final bool current;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final prog = ref.watch(_nowOnProvider(channel.id)).valueOrNull;
    final logo = channel.logoUrl;
    return TvFocusable(
      onTap: onTap,
      autofocus: autofocus,
      wrapsGesture: false,
      ensureVisibleOnFocus: true,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: current
              ? scheme.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 76,
                    height: 48,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: logoTileColors,
                      ),
                    ),
                    child: logo == null || logo.isEmpty
                        ? const Icon(Icons.tv_rounded, color: Colors.white54)
                        : CachedNetworkImage(
                            imageUrl: logo,
                            fit: BoxFit.contain,
                            memCacheWidth: 160,
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.tv_rounded,
                                color: Colors.white54),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          context.displayName(channel.name),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall!.copyWith(
                              color: current ? scheme.primary : null),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          current
                              ? 'Now watching'
                              : prog?.title ?? 'Live',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall!.copyWith(
                              color: scheme.onSurfaceVariant),
                        ),
                        if (prog != null) ...[
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: prog
                                  .progressAt(DateTime.now())
                                  .clamp(0.0, 1.0),
                              minHeight: 3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (current) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.equalizer_rounded, color: scheme.primary),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
