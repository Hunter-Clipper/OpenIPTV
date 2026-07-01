import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';

class ParentalScreen extends ConsumerStatefulWidget {
  const ParentalScreen({super.key});

  @override
  ConsumerState<ParentalScreen> createState() => _ParentalScreenState();
}

class _ParentalScreenState extends ConsumerState<ParentalScreen> {
  Future<void> _setProtectionEnabled(AppPreferences prefs, bool v) async {
    await prefs.setParentalProtectionEnabled(v);
    if (!v) {
      ref.read(parentalSessionUnlockedProvider.notifier).state = const {};
    }
    if (mounted) setState(() {});
  }

  Future<void> _removeLockedCat(AppPreferences prefs, String cat) async {
    final cats = prefs.parentalLockedCategories.toList()..remove(cat);
    await prefs.setParentalLockedCategories(cats);
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;

    if (prefs == null || activeProfile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!activeProfile.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parental Controls')),
        body: const Center(child: Text('Admins only.')),
      );
    }

    final theme = Theme.of(context);
    final locked = prefs.parentalLockedCategories;
    final enabled = prefs.parentalProtectionEnabled;

    return Scaffold(
      appBar: AppBar(title: const Text('Parental Controls')),
      body: ListView(
        children: [
          _SectionHeader(title: 'Protection'),
          SwitchListTile(
            secondary: Icon(
              enabled ? Icons.lock_outline : Icons.lock_open_outlined,
              color: enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            title: const Text('Parental Protection'),
            subtitle: Text(
              enabled
                  ? 'Adult and locked categories require an admin PIN'
                  : 'Disabled — all content visible',
            ),
            value: enabled,
            onChanged: (v) => _setProtectionEnabled(prefs, v),
          ),

          // Locked category list
          if (enabled) ...[
            _SectionHeader(title: 'Locked Categories'),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Adult content is locked automatically by keyword. '
                'Categories below were added by the playlist scan.',
                style: theme.textTheme.bodySmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (locked.isEmpty)
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('No manually-locked categories'),
              )
            else
              ...locked.map((cat) => ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(cat),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.error),
                      tooltip: 'Remove from locked list',
                      onPressed: () => _removeLockedCat(prefs, cat),
                    ),
                  )),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelMedium!
            .copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
