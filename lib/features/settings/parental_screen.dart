import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/parental_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';
import 'package:open_iptv/shared/utils/display_name.dart';
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
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;

    if (prefs == null || activeProfile == null) {
      return const Scaffold(
        body: LoadingView(),
      );
    }

    if (!activeProfile.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.parentalTitle)),
        body: Center(child: Text(l10n.parentalAdminsOnly)),
      );
    }

    final theme = Theme.of(context);
    final locked = prefs.parentalLockedCategories;
    final enabled = prefs.parentalProtectionEnabled;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.parentalTitle)),
      body: TvFollowFocus(
          focusFirst: true,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              SettingsGroup(title: l10n.parentalProtectionGroup, children: [
                TvActivatable(
                  autofocus: true,
                  onTap: () => _setProtectionEnabled(prefs, !enabled),
                  builder: (_) => SwitchListTile(
                    secondary: IconBadge(
                      icon: enabled
                          ? Icons.lock_outline
                          : Icons.lock_open_outlined,
                    ),
                    title: Text(l10n.parentalProtectionTitle),
                    subtitle: Text(
                      enabled
                          ? l10n.parentalProtectionOn
                          : l10n.parentalProtectionOff,
                      style: theme.textTheme.bodySmall,
                    ),
                    value: enabled,
                    onChanged: (v) => _setProtectionEnabled(prefs, v),
                  ),
                ),
              ]),

              // Locked category list
              if (enabled)
                SettingsGroup(
                  title: l10n.parentalLockedGroup,
                  description: l10n.parentalLockedDescription,
                  children: [
                    if (locked.isEmpty)
                      ListTile(
                        leading: const IconBadge(icon: Icons.info_outline),
                        title: Text(l10n.parentalNoLocked),
                      )
                    else
                      ...locked.map((cat) => ListTile(
                            leading: const IconBadge(icon: Icons.lock_outline),
                            title: Text(context.displayName(cat)),
                            trailing: TvActivatable(
                              round: true,
                              onTap: () => _removeLockedCat(prefs, cat),
                              builder: (onTap) => IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: theme.colorScheme.error),
                                tooltip: l10n.parentalRemoveTooltip,
                                onPressed: onTap,
                              ),
                            ),
                          )),
                  ],
                ),
            ],
          )),
    );
  }
}
