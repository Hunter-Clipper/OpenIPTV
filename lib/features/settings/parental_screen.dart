import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/admin_biometric.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
import 'package:open_iptv/shared/widgets/pin_field.dart';
import 'package:open_iptv/shared/widgets/settings_group.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

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

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Turning fingerprint / face unlock on takes the admin PIN — never a
  /// scan — and then a scan to set up the device key. Off needs nothing.
  Future<void> _setBiometric(AppPreferences prefs, bool v) async {
    final biometric = ref.read(adminBiometricProvider);
    if (!v) {
      await biometric.disable();
      await prefs.setAdminBiometricUnlock(false);
      if (mounted) setState(() {});
      return;
    }
    final pin = await showPinEntryDialog(
      context,
      title: 'Enter admin PIN',
      message: 'To turn on fingerprint and face unlock',
      confirmLabel: 'Continue',
    );
    if (pin == null || !mounted) return;
    if (!await ref.read(profileServiceProvider).verifyAnyAdminPin(pin)) {
      _say('Incorrect PIN');
      return;
    }
    final outcome = await biometric.enable();
    if (outcome == BiometricOutcome.success) {
      await prefs.setAdminBiometricUnlock(true);
      _say('Fingerprint and face unlock is on');
    } else if (outcome != BiometricOutcome.fallback) {
      _say("Couldn't turn on fingerprint and face unlock on this device.");
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
        body: LoadingView(),
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
    final biometricAvailable =
        ref.watch(adminBiometricAvailableProvider).valueOrNull ?? false;
    final biometricOn = prefs.adminBiometricUnlock;
    final canUseBiometric = activeProfile.hasPin;

    return Scaffold(
      appBar: AppBar(title: const Text('Parental Controls')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SettingsGroup(title: 'Protection', children: [
            TvActivatable(
              autofocus: true,
              onTap: () => _setProtectionEnabled(prefs, !enabled),
              builder: (_) => SwitchListTile(
                secondary: IconBadge(
                  icon: enabled
                      ? Icons.lock_outline
                      : Icons.lock_open_outlined,
                ),
                title: const Text('Parental Protection'),
                subtitle: Text(
                  enabled
                      ? 'Adult and locked categories require an admin PIN'
                      : 'Off — all content is visible',
                  style: theme.textTheme.bodySmall,
                ),
                value: enabled,
                onChanged: (v) => _setProtectionEnabled(prefs, v),
              ),
            ),
          ]),

          // Fingerprint / face for admin PIN prompts (#47). Phones and
          // tablets with strong biometrics only — never on TV.
          if (biometricAvailable)
            SettingsGroup(
              title: 'Admin Unlock',
              description: 'Anyone whose fingerprint or face is set up on '
                  'this device can unlock admin prompts. Adding a new '
                  'fingerprint or face turns this off until you turn it '
                  'on again.',
              children: [
                TvActivatable(
                  onTap: canUseBiometric
                      ? () => _setBiometric(prefs, !biometricOn)
                      : null,
                  builder: (_) => SwitchListTile(
                    secondary: const IconBadge(icon: Icons.fingerprint),
                    title: const Text('Unlock with Fingerprint or Face'),
                    subtitle: Text(
                      canUseBiometric
                          ? 'Use it instead of typing the admin PIN on '
                              'this device'
                          : 'Set a PIN on your profile first',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: biometricOn && canUseBiometric,
                    onChanged: canUseBiometric
                        ? (v) => _setBiometric(prefs, v)
                        : null,
                  ),
                ),
              ],
            ),

          // Locked category list
          if (enabled)
            SettingsGroup(
              title: 'Locked Categories',
              description: 'Adult content is locked automatically. '
                  'Categories below were added by the playlist scan.',
              children: [
                if (locked.isEmpty)
                  const ListTile(
                    leading: IconBadge(icon: Icons.info_outline),
                    title: Text('No other locked categories'),
                  )
                else
                  ...locked.map((cat) => ListTile(
                        leading: const IconBadge(icon: Icons.lock_outline),
                        title: Text(context.displayName(cat)),
                        trailing: TvActivatable(
                          onTap: () => _removeLockedCat(prefs, cat),
                          builder: (onTap) => IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: theme.colorScheme.error),
                            tooltip: 'Remove from locked list',
                            onPressed: onTap,
                          ),
                        ),
                      )),
              ],
            ),
        ],
      ),
    );
  }
}
