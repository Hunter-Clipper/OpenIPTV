import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/services/admin_biometric.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/shared/widgets/loading_view.dart';
import 'package:open_iptv/shared/widgets/parental_pin_dialog.dart';
import 'package:open_iptv/shared/widgets/pin_field.dart';
import 'package:open_iptv/shared/widgets/profile_avatar.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

class ProfilePickerScreen extends ConsumerWidget {
  /// Called after a profile is successfully selected.
  const ProfilePickerScreen({super.key, required this.onPicked});

  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            // Opaque blends: a translucent tint let the sheet colour show
            // through as a heavy green wash.
            colors: [
              Color.alphaBlend(theme.colorScheme.primary.withValues(alpha: 0.10),
                  theme.scaffoldBackgroundColor),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: profilesAsync.when(
            loading: () => const LoadingView(),
            error: (_, __) =>
                const Center(child: Text('Could not load profiles.')),
            data: (profiles) => Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo_mark.png',
                      width: 84,
                      height: 84,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Who's watching?",
                      style: theme.textTheme.displaySmall!
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 28,
                        runSpacing: 28,
                        children: [
                          for (var i = 0; i < profiles.length; i++)
                            _ProfileCard(
                              profile: profiles[i],
                              autofocus: i == 0,
                              onSelected: () =>
                                  _selectProfile(context, ref, profiles[i]),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectProfile(
      BuildContext context, WidgetRef ref, Profile profile) async {
    // The admin's own profile counts as an admin PIN prompt (#47): a
    // fingerprint / face may stand in for it. Other profiles' PINs don't.
    String? notice;
    final scan = profile.hasPin && profile.isAdmin
        ? await tryAdminBiometric(ref, 'Switch to ${profile.name}',
            onNotice: (m) => notice = m)
        : AdminScanResult.usePin;
    if (scan == AdminScanResult.alreadyShowing) return;
    if (scan == AdminScanResult.unlocked) {
      await ref
          .read(profileServiceProvider)
          .switchToProfile(profile.id, pinVerified: true);
    } else if (profile.hasPin) {
      if (!context.mounted) return;
      final pin = await _showPinDialog(context, profile.name, notice);
      if (pin == null) return;
      final ok = await ref
          .read(profileServiceProvider)
          .switchToProfile(profile.id, pin: pin);
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect PIN')),
          );
        }
        return;
      }
    } else {
      await ref.read(profileServiceProvider).switchToProfile(profile.id);
    }
    ref.invalidate(activeProfileProvider);
    onPicked();
  }

  Future<String?> _showPinDialog(
          BuildContext context, String name, String? message) =>
      showPinEntryDialog(context,
          title: 'Enter PIN for $name', message: message);
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({
    required this.profile,
    required this.onSelected,
    this.autofocus = false,
  });

  final Profile profile;
  final VoidCallback onSelected;
  final bool autofocus;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.profile;
    final isTV = PlatformHelper.isTV(context);
    final size = isTV ? 132.0 : 104.0;
    final lit = _focused && isTV;

    return TvFocusable(
      onTap: widget.onSelected,
      autofocus: widget.autofocus,
      showFocusRing: false,
      onFocusChange: (f) => setState(() => _focused = f),
      child: SizedBox(
        width: size + 24,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: lit ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ProfileAvatar(
                    emoji: profile.avatarEmoji,
                    name: profile.name,
                    size: size,
                    highlighted: lit,
                  ),
                  if (profile.hasPin)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.lock_rounded,
                            size: 16, color: theme.colorScheme.onSurface),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              profile.name,
              style: theme.textTheme.titleMedium!.copyWith(
                fontWeight: lit ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (profile.isKidsProfile)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Kids',
                  style: theme.textTheme.labelMedium!
                      .copyWith(color: theme.colorScheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
