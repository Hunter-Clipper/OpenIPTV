import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

/// The AppBar actions shared by every browse screen (Live TV, Movies, Series
/// and their category/genre screens). They each watch the preference they
/// toggle, so a screen only has to drop them into `actions:`.

/// Toggles the global A–Z / provider-order content sort.
class SortToggleAction extends ConsumerWidget {
  const SortToggleAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(contentSortProvider);
    return TvActivatable(
      onTap: () async {
        final prefs = await ref.read(appPreferencesProvider.future);
        await setContentSort(ref, sort == 'az' ? 'provider' : 'az', prefs);
      },
      builder: (onTap) => IconButton(
        icon: Icon(sort == 'az' ? Icons.sort_by_alpha : Icons.sort),
        tooltip: sort == 'az' ? 'Sorted A–Z' : 'Provider order',
        onPressed: onTap,
      ),
    );
  }
}

/// Toggles one section's grid/list view mode. [provider] and [setMode] are
/// the matching pair from theme_providers.dart — e.g. [viewModeLiveProvider]
/// with [setViewModeLive].
class ViewModeToggleAction extends ConsumerWidget {
  const ViewModeToggleAction({
    super.key,
    required this.provider,
    required this.setMode,
  });

  final StateProvider<String> provider;
  final Future<void> Function(WidgetRef ref, String mode, AppPreferences prefs)
      setMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewMode = ref.watch(provider);
    return TvActivatable(
      onTap: () async {
        final prefs = await ref.read(appPreferencesProvider.future);
        await setMode(ref, viewMode == 'grid' ? 'list' : 'grid', prefs);
      },
      builder: (onTap) => IconButton(
        icon: Icon(viewMode == 'grid' ? Icons.view_list : Icons.grid_view),
        tooltip: viewMode == 'grid'
            ? 'Switch to list view'
            : 'Switch to grid view',
        onPressed: onTap,
      ),
    );
  }
}

/// Opens the Settings screen.
class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context) {
    return TvActivatable(
      onTap: () => context.push('/settings'),
      builder: (onTap) => IconButton(
        icon: const Icon(Icons.settings_outlined),
        tooltip: 'Settings',
        onPressed: onTap,
      ),
    );
  }
}
