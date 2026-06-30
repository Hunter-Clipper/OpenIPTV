import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/widgets/parental_pin_dialog.dart';

class ParentalScreen extends ConsumerStatefulWidget {
  const ParentalScreen({super.key});

  @override
  ConsumerState<ParentalScreen> createState() => _ParentalScreenState();
}

class _ParentalScreenState extends ConsumerState<ParentalScreen> {
  // ---------------------------------------------------------------------------
  // PIN management
  // ---------------------------------------------------------------------------

  Future<void> _setPin(AppPreferences prefs) async {
    final pin1 = await showParentalPinEntry(context, 'Enter new PIN');
    if (!mounted || pin1 == null) return;
    final pin2 = await showParentalPinEntry(context, 'Confirm PIN');
    if (!mounted || pin2 == null) return;
    if (pin1 != pin2) {
      _snack('PINs do not match — try again');
      return;
    }
    await prefs.setParentalPinHash(hashParentalPin(pin1));
    if (mounted) setState(() {});
  }

  Future<void> _changePin(AppPreferences prefs) async {
    final current = await showParentalPinEntry(context, 'Enter current PIN');
    if (!mounted || current == null) return;
    if (hashParentalPin(current) != prefs.parentalPinHash) {
      _snack('Incorrect PIN');
      return;
    }
    final pin1 = await showParentalPinEntry(context, 'Enter new PIN');
    if (!mounted || pin1 == null) return;
    final pin2 = await showParentalPinEntry(context, 'Confirm new PIN');
    if (!mounted || pin2 == null) return;
    if (pin1 != pin2) {
      _snack('PINs do not match — try again');
      return;
    }
    await prefs.setParentalPinHash(hashParentalPin(pin1));
    if (mounted) {
      setState(() {});
      _snack('PIN updated');
    }
  }

  Future<void> _removePin(AppPreferences prefs) async {
    final current =
        await showParentalPinEntry(context, 'Enter PIN to disable lock');
    if (!mounted || current == null) return;
    if (hashParentalPin(current) != prefs.parentalPinHash) {
      _snack('Incorrect PIN');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disable Parental Lock'),
        content: const Text(
            'This removes PIN protection. All locked content becomes accessible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Disable')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await prefs.setParentalPinHash(null);
    ref.read(parentalSessionUnlockedProvider.notifier).state = const {};
    if (mounted) setState(() {});
  }

  Future<void> _removeLockedCat(AppPreferences prefs, String cat) async {
    final cats = prefs.parentalLockedCategories.toList()..remove(cat);
    await prefs.setParentalLockedCategories(cats);
    if (mounted) setState(() {});
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    if (prefs == null) {
      return const Scaffold(
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final locked = prefs.parentalLockedCategories;

    return Scaffold(
      appBar: AppBar(title: const Text('Parental Controls')),
      body: ListView(
        children: [
          // Status / PIN management
          _SectionHeader(title: 'Protection'),
          ListTile(
            leading: Icon(
              prefs.parentalEnabled
                  ? Icons.lock_outline
                  : Icons.lock_open_outlined,
              color: prefs.parentalEnabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            title: const Text('Parental Lock'),
            subtitle: Text(prefs.parentalEnabled ? 'Enabled' : 'Disabled'),
            trailing: prefs.parentalEnabled
                ? null
                : FilledButton.tonal(
                    onPressed: () => _setPin(prefs),
                    child: const Text('Set PIN'),
                  ),
          ),
          if (prefs.parentalEnabled) ...[
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Change PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _changePin(prefs),
            ),
            ListTile(
              leading: Icon(Icons.lock_open_outlined,
                  color: theme.colorScheme.error),
              title: Text('Disable Parental Lock',
                  style: TextStyle(color: theme.colorScheme.error)),
              onTap: () => _removePin(prefs),
            ),
          ],

          // Locked category list
          if (prefs.parentalEnabled) ...[
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
