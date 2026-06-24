import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/shared/widgets/info_tooltip.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tooltipController = InfoTooltipController();
    final theme = Theme.of(context);

    // Derive active profile for the subtitle.
    final profile = ref.watch(activeProfileProvider).valueOrNull;

    return InfoTooltipScope(
      controller: tooltipController,
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          children: [
            // --------------- PROFILES ---------------
            _SectionHeader(title: 'Account'),
            ListTile(
              leading: profile != null
                  ? Text(profile.avatarEmoji,
                      style: const TextStyle(fontSize: 28))
                  : const Icon(Icons.person_outline),
              title: const Text('Profiles'),
              subtitle: profile != null
                  ? Text(profile.name,
                      style: theme.textTheme.bodySmall)
                  : const Text('No profile selected'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/profiles'),
            ),

            // --------------- SOURCES ---------------
            _SectionHeader(title: 'Sources'),
            Consumer(builder: (context, ref, _) {
              final sources = ref.watch(allSourcesProvider);
              return ListTile(
                leading: const Icon(Icons.playlist_play_outlined),
                title: const Text('Sources'),
                subtitle: sources.when(
                  loading: () => null,
                  error: (_, __) => null,
                  data: (list) => Text(
                    list.isEmpty
                        ? 'No sources added'
                        : '${list.length} source${list.length == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openSourcesPage(context, ref),
              );
            }),

            // --------------- BACKUP ---------------
            _SectionHeader(title: 'Data'),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup & Restore'),
              subtitle: Text(
                'Export or import your profile and sources',
                style: theme.textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/backup'),
            ),

            // --------------- PLAYBACK ---------------
            _SectionHeader(title: 'Playback'),
            InfoTooltip(
              id: 'settings_continue_watching',
              title: 'Continue Watching',
              body:
                  'When this is on, OpenIPTV remembers where you left off '
                  'in movies and series. The next time you open them, '
                  "you'll be offered the option to resume.",
              child: _ToggleTile(
                icon: Icons.play_circle_outline,
                title: 'Continue Watching',
                value: true, // TODO: wire from AppPreferences in Phase 1 completion
                onChanged: (_) {},
              ),
            ),
            InfoTooltip(
              id: 'settings_channel_sort',
              title: 'Channel Sort Order',
              body:
                  'Provider order follows the order your provider arranged '
                  'the channels. A-Z sorts them alphabetically by name. '
                  'Custom order lets you drag channels into any order you like.',
              child: ListTile(
                leading: const Icon(Icons.sort),
                title: const Text('Channel Sort Order'),
                subtitle: const Text('Provider order'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showSortOrderDialog(context),
              ),
            ),
            // --------------- APPEARANCE ---------------
            _SectionHeader(title: 'Appearance'),
            InfoTooltip(
              id: 'settings_hidden_cats',
              title: 'Hidden Categories',
              body:
                  "Categories you've hidden won't appear in your channel "
                  "list. Your channels are still there — they're just out "
                  "of the way. You can unhide them here at any time.",
              child: ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Hidden Categories'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showHiddenCategoriesPage(context),
              ),
            ),

            // --------------- ABOUT ---------------
            _SectionHeader(title: 'About'),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) {
                final version = snap.hasData
                    ? 'Version ${snap.data!.version}'
                    : 'OpenIPTV';
                return ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About OpenIPTV'),
                  subtitle: Text(version),
                  onTap: () => _showAboutDialog(context, snap.data),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _openSourcesPage(BuildContext context, WidgetRef ref) {
    // Sources management: show a simple list with delete + refresh options.
    // Full sources page is a future enhancement; for Phase 1 we show a sheet.
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SourcesSheet(),
    );
  }

  void _showSortOrderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Channel Sort Order'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Provider order'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('A–Z'),
          ),
        ],
      ),
    );
  }

  void _showHiddenCategoriesPage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _HiddenCategoriesSheet(),
    );
  }

  void _showAboutDialog(BuildContext context, PackageInfo? info) {
    showAboutDialog(
      context: context,
      applicationName: 'OpenIPTV',
      applicationVersion: info != null ? info.version : '',
      applicationLegalese:
          '© 2024 OpenIPTV contributors. Licensed under GPL-3.0.',
      children: [
        const SizedBox(height: 16),
        const Text(
          'An open-source, ad-free, cross-platform IPTV client. '
          'No accounts required. No telemetry. No ads. Ever.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}

// ---------------------------------------------------------------------------
// Sources bottom sheet
// ---------------------------------------------------------------------------

class _SourcesSheet extends ConsumerStatefulWidget {
  const _SourcesSheet();

  @override
  ConsumerState<_SourcesSheet> createState() => _SourcesSheetState();
}

class _SourcesSheetState extends ConsumerState<_SourcesSheet> {
  final _refreshingPlaylist = <String>{};
  final _refreshingEpg = <String>{};

  Future<void> _refreshPlaylist(String id) async {
    if (_refreshingPlaylist.contains(id) || _refreshingEpg.contains(id)) return;
    setState(() => _refreshingPlaylist.add(id));
    try {
      final sources = await ref.read(allSourcesProvider.future);
      final source = sources.firstWhere((s) => s.id == id);
      await ref.read(sourceManagerProvider).refreshPlaylist(source);
      ref.invalidate(allSourcesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${source.nickname}" playlist refreshed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Playlist refresh failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingPlaylist.remove(id));
    }
  }

  Future<void> _refreshEpg(String id) async {
    if (_refreshingPlaylist.contains(id) || _refreshingEpg.contains(id)) return;
    setState(() => _refreshingEpg.add(id));
    try {
      final sources = await ref.read(allSourcesProvider.future);
      final source = sources.firstWhere((s) => s.id == id);
      await ref.read(sourceManagerProvider).refreshEpgOnly(source);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${source.nickname}" TV guide refreshed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('TV guide refresh failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingEpg.remove(id));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String id,
    String nickname,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Source?'),
        content: Text(
            'This will remove "$nickname" and all its channels, '
            'movies, and series. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sourceManagerProvider).deleteSource(id);
      ref.invalidate(allSourcesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(allSourcesProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Sources',
                    style: Theme.of(context).textTheme.titleLarge),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/onboarding');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: sourcesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  const Center(child: Text("Couldn't load sources.")),
              data: (sources) {
                if (sources.isEmpty) {
                  return const Center(child: Text('No sources yet.'));
                }
                return ListView.builder(
                  controller: controller,
                  itemCount: sources.length,
                  itemBuilder: (context, i) {
                    final s = sources[i];
                    final isPlaylistRefreshing = _refreshingPlaylist.contains(s.id);
                    final isEpgRefreshing = _refreshingEpg.contains(s.id);
                    final isBusy = isPlaylistRefreshing || isEpgRefreshing;
                    return ListTile(
                      leading: const Icon(Icons.playlist_play),
                      title: Text(s.nickname),
                      subtitle: Text(
                        s.type.name.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Playlist refresh
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: isPlaylistRefreshing
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.sync, size: 20),
                                    tooltip: 'Refresh Playlist',
                                    onPressed: isBusy ? null : () => _refreshPlaylist(s.id),
                                  ),
                          ),
                          // EPG refresh
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: isEpgRefreshing
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.tv, size: 20),
                                    tooltip: 'Refresh TV Guide',
                                    onPressed: isBusy ? null : () => _refreshEpg(s.id),
                                  ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            tooltip: 'Remove',
                            onPressed: isBusy
                                ? null
                                : () => _confirmDelete(context, s.id, s.nickname),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hidden categories sheet
// ---------------------------------------------------------------------------

class _HiddenCategoriesSheet extends ConsumerWidget {
  const _HiddenCategoriesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider).valueOrNull;
    final hidden = profile?.hiddenCategories ?? [];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Hidden Categories',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          const Divider(height: 1),
          Expanded(
            child: hidden.isEmpty
                ? const Center(
                    child: Text('No categories are hidden.'))
                : ListView.builder(
                    controller: controller,
                    itemCount: hidden.length,
                    itemBuilder: (context, i) => ListTile(
                      title: Text(hidden[i]),
                      trailing: TextButton(
                        onPressed: () {
                          // Unhide logic via profileService
                        },
                        child: const Text('Show'),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
