import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';

class ProfilePickerScreen extends ConsumerWidget {
  /// Called after a profile is successfully selected.
  const ProfilePickerScreen({super.key, required this.onPicked});

  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Image.asset('assets/images/app_icon.png', width: 72, height: 72),
            const SizedBox(height: 16),
            Text('Who\'s watching?', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Select your profile to continue',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 40),
            Expanded(
              child: profilesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('Could not load profiles.')),
                data: (profiles) => GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: profiles.length,
                  itemBuilder: (context, i) => _ProfileCard(
                    profile: profiles[i],
                    onSelected: () =>
                        _selectProfile(context, ref, profiles[i]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectProfile(
      BuildContext context, WidgetRef ref, Profile profile) async {
    if (profile.hasPin) {
      final pin = await _showPinDialog(context, profile.name);
      if (pin == null) return;
      final ok = await ref
          .read(profileServiceProvider)
          .switchToProfile(profile.id, pin: pin);
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect PIN. Try again.')),
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

  Future<String?> _showPinDialog(BuildContext context, String name) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Enter PIN for $name'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          autofocus: true,
          decoration: const InputDecoration(hintText: 'PIN'),
          onSubmitted: (_) =>
              Navigator.of(ctx).pop(controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onSelected});

  final Profile profile;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    profile.avatarEmoji,
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
              ),
              if (profile.hasPin)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock,
                      size: 16, color: theme.colorScheme.primary),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            profile.name,
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
