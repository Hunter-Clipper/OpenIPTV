import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/parsers/xtream_client.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/auto_refresh_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/settings/profile_picker_screen.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
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
    final isAdmin = profile?.isAdmin ?? false;

    return InfoTooltipScope(
      controller: tooltipController,
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          children: [
            // --------------- PROFILES ---------------
            _SectionHeader(title: 'Account'),
            InfoTooltip(
              id: 'settings_profile',
              title: 'Profile',
              body: 'OpenIPTV supports multiple profiles on one device. '
                  'Each profile has its own watch history, favorites, hidden '
                  'categories, and PIN lock. Tap to manage profiles.',
              child: ListTile(
                leading: profile != null
                    ? Text(profile.avatarEmoji,
                        style: const TextStyle(fontSize: 28))
                    : const Icon(Icons.person_outline),
                title: const Text('Profile'),
                subtitle: profile != null
                    ? Text(profile.name, style: theme.textTheme.bodySmall)
                    : const Text('No profile selected'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/profiles'),
              ),
            ),
            Consumer(builder: (context, ref, _) {
              final all = ref.watch(allProfilesProvider);
              final count = all.valueOrNull?.length ?? 0;
              if (count <= 1) return const SizedBox.shrink();
              return InfoTooltip(
                id: 'settings_switch_profile',
                title: 'Switch Profile',
                body: 'Quickly change the active profile without going into '
                    'profile management. Useful when sharing a device with '
                    'family or roommates.',
                child: ListTile(
                  leading: const Icon(Icons.switch_account_outlined),
                  title: const Text('Switch Profile'),
                  subtitle: Text('$count profiles available',
                      style: theme.textTheme.bodySmall),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => ProfilePickerScreen(
                      onPicked: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              );
            }),

            // --------------- SOURCES (admin only) ---------------
            if (isAdmin) ...[
              _SectionHeader(title: 'Sources'),
              Consumer(builder: (context, ref, _) {
                final sources = ref.watch(allSourcesProvider);
                return InfoTooltip(
                  id: 'settings_sources',
                  title: 'Sources',
                  body: 'An IPTV source is your provider connection — either '
                      'an M3U playlist URL or Xtream Codes credentials. '
                      'Sources supply your channels, movies, and series. '
                      'You can add multiple sources and refresh them here.',
                  child: ListTile(
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
                  ),
                );
              }),

              // --------------- BACKUP (admin only) ---------------
              _SectionHeader(title: 'Data'),
              InfoTooltip(
                id: 'settings_backup',
                title: 'Backup & Restore',
                body: 'Export your profiles and sources to a single '
                    '.iptvprofile file you can store anywhere. Restore it '
                    'later to move to a new device or recover from a reset. '
                    'Stream credentials are included — keep the file safe.',
                child: ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Backup & Restore'),
                  subtitle: Text(
                    'Export or import your profile and sources',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/backup'),
                ),
              ),

              // --------------- AUTO-REFRESH (admin only) ---------------
              Consumer(builder: (context, ref, _) {
                final hours = ref.watch(refreshIntervalHoursProvider);
                return InfoTooltip(
                  id: 'settings_auto_refresh',
                  title: 'Auto-Refresh',
                  body:
                      'Automatically refreshes your playlists and TV guide '
                      'in the background so channels and schedules stay '
                      'current without manual refreshing.',
                  child: ListTile(
                    leading: const Icon(Icons.autorenew),
                    title: const Text('Auto-Refresh'),
                    subtitle: Text(
                      _refreshIntervalLabel(hours),
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showAutoRefreshDialog(context, ref, hours),
                  ),
                );
              }),
              Consumer(builder: (context, ref, _) {
                final hours = ref.watch(refreshIntervalHoursProvider);
                if (hours <= 0) return const SizedBox.shrink();
                final notifyEnabled =
                    ref.watch(refreshNotificationsEnabledProvider);
                return _ToggleTile(
                  icon: Icons.notifications_outlined,
                  title: 'Refresh Notifications',
                  value: notifyEnabled,
                  onChanged: (v) async {
                    final prefs =
                        await ref.read(appPreferencesProvider.future);
                    await setRefreshNotificationsEnabled(ref, v, prefs);
                  },
                );
              }),

              // --------------- PARENTAL (admin only) ---------------
              _SectionHeader(title: 'Family'),
              ListTile(
                leading: const Icon(Icons.family_restroom_outlined),
                title: const Text('Parental Controls'),
                subtitle: Text(
                  'PIN-protect adult and locked categories',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/parental'),
              ),
            ],

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
            Consumer(builder: (context, ref, _) {
              final sort = ref.watch(contentSortProvider);
              return InfoTooltip(
                id: 'settings_sort_order',
                title: 'Content Sort Order',
                body: 'Controls how channels, movies, and series are listed. '
                    'Provider order shows them in the sequence your IPTV '
                    'provider sends them. A–Z sorts them alphabetically.',
                child: ListTile(
                  leading: const Icon(Icons.sort),
                  title: const Text('Content Sort Order'),
                  subtitle: Text(
                    sort == 'az' ? 'A–Z' : 'Provider order',
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showSortOrderDialog(context, ref, sort),
                ),
              );
            }),
            // --------------- APPEARANCE ---------------
            _SectionHeader(title: 'Appearance'),
            Consumer(builder: (context, ref, _) {
              final accent = ref.watch(accentColorProvider);
              return InfoTooltip(
                id: 'settings_accent_color',
                title: 'Accent Color',
                body: 'Changes the highlight color used throughout the app — '
                    'active buttons, selected items, progress bars, and '
                    'other indicators. Pick whichever color you like best.',
                child: ListTile(
                  leading: CircleAvatar(
                      backgroundColor: accent, radius: 12),
                  title: const Text('Accent Color'),
                  subtitle: Text(
                    AppTheme.accentSwatches
                        .firstWhere((s) => s.color == accent,
                            orElse: () =>
                                (label: 'Custom', color: accent))
                        .label,
                    style: theme.textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showAccentColorPicker(context, ref, accent),
                ),
              );
            }),
            if (isAdmin)
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
            InfoTooltip(
              id: 'settings_about',
              title: 'About OpenIPTV',
              body: 'Shows the current app version and license information. '
                  'OpenIPTV is open-source under the GPL-3.0 license — '
                  'no ads, no telemetry, no accounts. Ever.',
              child: FutureBuilder<PackageInfo>(
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

  Future<void> _showSortOrderDialog(
      BuildContext context, WidgetRef ref, String current) async {
    final prefs = await ref.read(appPreferencesProvider.future);
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Content Sort Order'),
        children: [
          SimpleDialogOption(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await setContentSort(ref, 'provider', prefs);
            },
            child: Row(children: [
              Icon(Icons.check,
                  size: 18,
                  color: current == 'provider'
                      ? Theme.of(ctx).colorScheme.primary
                      : Colors.transparent),
              const SizedBox(width: 8),
              const Text('Provider order'),
            ]),
          ),
          SimpleDialogOption(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await setContentSort(ref, 'az', prefs);
            },
            child: Row(children: [
              Icon(Icons.check,
                  size: 18,
                  color: current == 'az'
                      ? Theme.of(ctx).colorScheme.primary
                      : Colors.transparent),
              const SizedBox(width: 8),
              const Text('A–Z'),
            ]),
          ),
        ],
      ),
    );
  }

  String _refreshIntervalLabel(int hours) {
    switch (hours) {
      case 2:
        return 'Every 2 hours';
      case 6:
        return 'Every 6 hours';
      case 12:
        return 'Every 12 hours';
      case 24:
        return 'Every 24 hours';
      default:
        return 'Off';
    }
  }

  Future<void> _showAutoRefreshDialog(
      BuildContext context, WidgetRef ref, int current) async {
    final prefs = await ref.read(appPreferencesProvider.future);
    if (!context.mounted) return;
    final selected = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Auto-Refresh'),
        children: [0, 2, 6, 12, 24].map((hours) {
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(hours),
            child: Row(children: [
              Icon(Icons.check,
                  size: 18,
                  color: current == hours
                      ? Theme.of(ctx).colorScheme.primary
                      : Colors.transparent),
              const SizedBox(width: 8),
              Text(_refreshIntervalLabel(hours)),
            ]),
          );
        }).toList(),
      ),
    );
    if (selected == null || selected == current) return;
    if (!context.mounted) return;

    final turningOn = current <= 0 && selected > 0;
    await setRefreshIntervalHours(ref, selected, prefs);

    if (turningOn && context.mounted) {
      await _runAutoRefreshPermissionFlow(context);
    }
  }

  /// One-time rationale + permission chain, shown only when auto-refresh is
  /// turned on from Off. Declining either permission doesn't block enabling
  /// the feature — WorkManager still runs, just less reliably without the
  /// battery exemption, and silently without a visible notification if that
  /// permission is denied.
  Future<void> _runAutoRefreshPermissionFlow(BuildContext context) async {
    final wantsNotifications = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stay Informed'),
        content: const Text(
            'Allow notifications so OpenIPTV can let you know when a '
            'background refresh finishes or runs into a problem?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    if (wantsNotifications == true) {
      await requestNotificationPermission();
    }
    if (!context.mounted) return;

    final wantsBatteryExemption = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reliable Background Refresh'),
        content: const Text(
            'Some phones aggressively limit background apps to save '
            'battery, which can delay auto-refresh. Exempting OpenIPTV '
            'from battery optimization makes refreshes more reliable.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (wantsBatteryExemption == true) {
      await requestBatteryOptimizationExemption();
    }
  }

  void _showAccentColorPicker(
      BuildContext context, WidgetRef ref, Color current) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text('Accent Color',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: AppTheme.accentSwatches.map((swatch) {
                  final selected = swatch.color == current;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final prefs =
                          await ref.read(appPreferencesProvider.future);
                      await setAccentColor(ref, swatch.color, prefs);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: swatch.color,
                            shape: BoxShape.circle,
                            border: selected
                                ? Border.all(
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .onSurface,
                                    width: 3)
                                : null,
                          ),
                          child: selected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 26)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(swatch.label,
                            style: Theme.of(ctx).textTheme.bodySmall),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
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
          '© 2026 OpenIPTV contributors. Licensed under GPL-3.0.',
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

  Future<void> _switchSource(BuildContext context, Source source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch Source?'),
        content: Text(
          'Switch to "${source.nickname}"?\n\n'
          'The channel list, movies, and series will update to show only this source.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final prefs = await ref.read(appPreferencesProvider.future);
      await setActiveSource(ref, source.id, prefs);
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
      // Clear active source if it was the deleted one.
      if (ref.read(activeSourceIdProvider) == id) {
        final prefs = await ref.read(appPreferencesProvider.future);
        await setActiveSource(ref, null, prefs);
      }
      ref.invalidate(allSourcesProvider);
    }
  }

  void _showInfoPanel(BuildContext context, Source source) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SourceInfoSheet(source: source),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(allSourcesProvider);
    final activeSourceId = ref.watch(activeSourceIdProvider);

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
          if (sourcesAsync.valueOrNull != null &&
              sourcesAsync.valueOrNull!.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Tap a source to make it active. Active source filters all content.',
                style: Theme.of(context).textTheme.bodySmall,
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
                final multiSource = sources.length > 1;
                return ListView.builder(
                  controller: controller,
                  itemCount: sources.length,
                  itemBuilder: (context, i) {
                    final s = sources[i];
                    final isActive = activeSourceId == s.id ||
                        (!multiSource && activeSourceId == null);
                    final isPlaylistRefreshing = _refreshingPlaylist.contains(s.id);
                    final isEpgRefreshing = _refreshingEpg.contains(s.id);
                    final isBusy = isPlaylistRefreshing || isEpgRefreshing;
                    return ListTile(
                      leading: isActive
                          ? Icon(Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary)
                          : const Icon(Icons.playlist_play),
                      title: Text(s.nickname),
                      subtitle: Text(
                        s.type.name.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: multiSource && !isActive && !isBusy
                          ? () => _switchSource(context, s)
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Source info
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              icon: const Icon(Icons.info_outline, size: 20),
                              tooltip: 'Source Info',
                              onPressed: () => _showInfoPanel(context, s),
                            ),
                          ),
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
// Source info bottom sheet (#22)
// ---------------------------------------------------------------------------

class _SourceInfoSheet extends StatefulWidget {
  const _SourceInfoSheet({required this.source});

  final Source source;

  @override
  State<_SourceInfoSheet> createState() => _SourceInfoSheetState();
}

class _SourceInfoSheetState extends State<_SourceInfoSheet> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _userInfo;
  Map<String, dynamic>? _serverInfo;

  @override
  void initState() {
    super.initState();
    if (widget.source.type == SourceType.xtream) _fetchInfo();
  }

  Future<void> _fetchInfo() async {
    setState(() { _loading = true; _error = null; });
    final client = XtreamClient(
      host: widget.source.xtreamHost!,
      username: widget.source.xtreamUsername!,
      password: widget.source.xtreamPassword!,
      sourceId: widget.source.id,
    );
    try {
      final info = await client.getServerInfo();
      if (mounted) {
        setState(() {
          _userInfo = info['user_info'] as Map<String, dynamic>?;
          _serverInfo = info['server_info'] as Map<String, dynamic>?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not fetch server info.'; _loading = false; });
    } finally {
      client.dispose();
    }
  }

  String _formatEpoch(dynamic value) {
    if (value == null) return '—';
    final epoch = int.tryParse(value.toString());
    if (epoch == null || epoch == 0) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = widget.source;
    final lastRefreshed = source.lastRefreshed;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(source.nickname, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              source.type == SourceType.xtream ? 'Xtream Codes' : 'M3U Playlist',
              style: theme.textTheme.bodySmall,
            ),
            const Divider(height: 28),
            if (source.type == SourceType.m3u) ...[
              _InfoRow('URL', source.m3uUrl ?? '—'),
              if (source.epgUrl != null)
                _InfoRow('EPG URL', source.epgUrl!),
              _InfoRow(
                'Last refreshed',
                lastRefreshed != null
                    ? '${lastRefreshed.year}-${lastRefreshed.month.toString().padLeft(2, '0')}-${lastRefreshed.day.toString().padLeft(2, '0')}'
                    : 'Never',
              ),
            ] else if (_loading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (_error != null) ...[
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ] else ...[
              _InfoRow('Status', '${_userInfo?['status'] ?? '—'}'),
              _InfoRow('Expires', _formatEpoch(_userInfo?['exp_date'])),
              _InfoRow('Active connections', '${_userInfo?['active_cons'] ?? '—'}'),
              _InfoRow('Max connections', '${_userInfo?['max_connections'] ?? '—'}'),
              _InfoRow('Trial', _userInfo?['is_trial'] == '1' ? 'Yes' : 'No'),
              const Divider(height: 24),
              _InfoRow('Server', '${_serverInfo?['url'] ?? source.xtreamHost ?? '—'}'),
              _InfoRow('Timezone', '${_serverInfo?['timezone'] ?? '—'}'),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
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
                        onPressed: profile == null
                            ? null
                            : () async {
                                await ref
                                    .read(profileServiceProvider)
                                    .unhideCategory(profile.id, hidden[i]);
                                ref.invalidate(activeProfileProvider);
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
