import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/shared/widgets/info_tooltip.dart';

/// Profile overview screen — shows the active profile and lets the user
/// manage settings, PIN, kids mode, and other profiles.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeProfileProvider);
    final allAsync = ref.watch(allProfilesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: activeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text("Couldn't load profile.")),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No active profile.'));
          }
          return ListView(
            children: [
              // ── Hero ──────────────────────────────────────────────
              _ProfileHero(
                profile: profile,
                onEdit: () => _showEditDialog(context, ref, profile),
              ),
              const Divider(height: 1),

              // ── Account ───────────────────────────────────────────
              _SectionHeader(title: 'Account'),
              InfoTooltipScope(
                controller: InfoTooltipController(),
                child: InfoTooltip(
                  id: 'kids_profile',
                  title: 'Kids Profile',
                  body:
                      'When turned on, this profile is marked as a '
                      'Kids profile. Use this together with Parental '
                      'Controls (coming soon) to restrict adult content.',
                  child: SwitchListTile(
                    secondary: const Icon(Icons.child_care_outlined),
                    title: const Text('Kids Profile'),
                    subtitle: Text(
                      profile.isKidsProfile
                          ? 'Adult content will be hidden'
                          : 'All content is visible',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: profile.isKidsProfile,
                    onChanged: (val) async {
                      await ref.read(profileServiceProvider).updateProfile(
                            profile.copyWith(
                                isKidsProfile: val,
                                updatedAt: DateTime.now()),
                          );
                      ref.invalidate(activeProfileProvider);
                    },
                  ),
                ),
              ),

              // ── Security ──────────────────────────────────────────
              _SectionHeader(title: 'Security'),
              ListTile(
                leading: Icon(profile.hasPin
                    ? Icons.lock_outlined
                    : Icons.lock_open_outlined),
                title: const Text('PIN Lock'),
                subtitle: Text(
                  profile.hasPin
                      ? 'PIN is set — tap to change or remove'
                      : 'No PIN — tap to set one',
                  style: theme.textTheme.bodySmall,
                ),
                trailing: profile.hasPin
                    ? Icon(Icons.check_circle,
                        color: theme.colorScheme.primary, size: 20)
                    : null,
                onTap: () => _showPinDialog(
                  context,
                  ref,
                  profile,
                  blockPinRemoval: profile.isAdmin &&
                      (allAsync.valueOrNull?.length ?? 1) > 1,
                ),
              ),

              // ── All Profiles (admin only) ─────────────────────────
              if (profile.isAdmin) ...[
                _SectionHeader(title: 'All Profiles'),
                allAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (all) => Column(
                    children: [
                      ...all.map((p) => _ProfileTile(
                            profile: p,
                            isActive: p.id == profile.id,
                            onEdit: () => _showEditDialog(context, ref, p),
                            onDelete: all.length > 1
                                ? () => _confirmDelete(context, ref, p)
                                : null,
                          )),
                      ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Add Profile'),
                        onTap: () => _showCreateDialog(context, ref),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, Profile profile) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _EditProfileDialog(profile: profile, ref: ref),
    );
    ref.invalidate(activeProfileProvider);
    ref.invalidate(allProfilesProvider);
  }

  Future<void> _showCreateDialog(
      BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _CreateProfileDialog(ref: ref),
    );
    ref.invalidate(allProfilesProvider);
  }

  Future<void> _showPinDialog(
    BuildContext context,
    WidgetRef ref,
    Profile profile, {
    bool blockPinRemoval = false,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _PinManagementDialog(
        profile: profile,
        ref: ref,
        blockPinRemoval: blockPinRemoval,
      ),
    );
    ref.invalidate(activeProfileProvider);
    ref.invalidate(allProfilesProvider);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Profile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: Text(
          'Deleting "${profile.name}" will remove all its favourites and '
          'settings. Your sources and channels are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(profileServiceProvider).deleteProfile(profile.id);
      ref.invalidate(allProfilesProvider);
      ref.invalidate(activeProfileProvider);
    } on StateError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Profile hero header
// ---------------------------------------------------------------------------

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, required this.onEdit});

  final Profile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    profile.avatarEmoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit, size: 14,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(profile.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Active',
                    style: theme.textTheme.bodySmall!
                        .copyWith(color: theme.colorScheme.primary)),
              ),
              if (profile.isKidsProfile) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Kids',
                      style: theme.textTheme.bodySmall!
                          .copyWith(color: Colors.green)),
                ),
              ],
              if (profile.hasPin) ...[
                const SizedBox(width: 6),
                Icon(Icons.lock, size: 14,
                    color: theme.colorScheme.onSurfaceVariant),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile list tile (for All Profiles section)
// ---------------------------------------------------------------------------

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.onEdit,
    required this.onDelete,
  });

  final Profile profile;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Stack(
        children: [
          Text(profile.avatarEmoji,
              style: const TextStyle(fontSize: 32)),
          if (isActive)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: theme.scaffoldBackgroundColor, width: 1.5),
                ),
              ),
            ),
        ],
      ),
      title: Text(profile.name),
      subtitle: Row(
        children: [
          if (isActive)
            Text('Active',
                style: theme.textTheme.bodySmall!
                    .copyWith(color: theme.colorScheme.primary)),
          if (isActive && profile.isKidsProfile) const Text(' · '),
          if (profile.isKidsProfile)
            Text('Kids', style: theme.textTheme.bodySmall),
          if ((isActive || profile.isKidsProfile) && profile.hasPin)
            const Text(' · '),
          if (profile.hasPin)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline,
                  size: 12,
                  color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 2),
              Text('PIN', style: theme.textTheme.bodySmall),
            ]),
        ],
      ),
      trailing: PopupMenuButton<_Action>(
        onSelected: (a) {
          if (a == _Action.edit) onEdit();
          if (a == _Action.delete) onDelete?.call();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: _Action.edit, child: Text('Edit')),
          if (onDelete != null) ...[
            const PopupMenuDivider(),
            const PopupMenuItem(
                value: _Action.delete, child: Text('Delete')),
          ],
        ],
      ),
    );
  }
}

enum _Action { edit, delete }

// ---------------------------------------------------------------------------
// Section header
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

// ---------------------------------------------------------------------------
// Edit profile dialog
// ---------------------------------------------------------------------------

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({required this.profile, required this.ref});
  final Profile profile;
  final WidgetRef ref;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _name;
  late String _emoji;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.profile.name);
    _emoji = widget.profile.avatarEmoji;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    try {
      await widget.ref.read(profileServiceProvider).updateProfile(
            widget.profile.copyWith(name: name, avatarEmoji: _emoji),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() => _error = "Couldn't save changes.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            const Text('Avatar'),
            const SizedBox(height: 8),
            _EmojiPicker(
              selected: _emoji,
              onSelected: (e) => setState(() => _emoji = e),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Create profile dialog
// ---------------------------------------------------------------------------

class _CreateProfileDialog extends StatefulWidget {
  const _CreateProfileDialog({required this.ref});
  final WidgetRef ref;

  @override
  State<_CreateProfileDialog> createState() => _CreateProfileDialogState();
}

class _CreateProfileDialogState extends State<_CreateProfileDialog> {
  final _name = TextEditingController();
  String _emoji = Profile.avatarOptions.first;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    try {
      await widget.ref
          .read(profileServiceProvider)
          .createProfile(name: name, avatarEmoji: _emoji);
      if (mounted) Navigator.of(context).pop();
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = "Couldn't create profile.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Name'),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              autofocus: true,
              decoration:
                  const InputDecoration(hintText: 'e.g. Kids, Living Room'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _create(),
            ),
            const SizedBox(height: 16),
            const Text('Avatar'),
            const SizedBox(height: 8),
            _EmojiPicker(
              selected: _emoji,
              onSelected: (e) => setState(() => _emoji = e),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _create, child: const Text('Create')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PIN management dialog
// ---------------------------------------------------------------------------

class _PinManagementDialog extends StatefulWidget {
  const _PinManagementDialog({
    required this.profile,
    required this.ref,
    this.blockPinRemoval = false,
  });
  final Profile profile;
  final WidgetRef ref;
  final bool blockPinRemoval;

  @override
  State<_PinManagementDialog> createState() => _PinManagementDialogState();
}

class _PinManagementDialogState extends State<_PinManagementDialog> {
  final _current = TextEditingController();
  final _newPin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _current.dispose();
    _newPin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPin = _newPin.text.trim();
    if (newPin != _confirm.text.trim()) {
      setState(() => _error = "PINs don't match.");
      return;
    }
    if (newPin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits.');
      return;
    }
    if (widget.profile.hasPin) {
      final ok = widget.ref
          .read(profileServiceProvider)
          .verifyPin(widget.profile, _current.text.trim());
      if (!ok) {
        setState(() => _error = 'Current PIN is incorrect.');
        return;
      }
    }
    await widget.ref
        .read(profileServiceProvider)
        .setPin(widget.profile.id, newPin);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove() async {
    try {
      await widget.ref.read(profileServiceProvider).clearPin(
            widget.profile.id,
            currentPin: _current.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError {
      setState(() => _error = 'Current PIN is incorrect.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.profile.hasPin ? 'Change PIN' : 'Set PIN'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.profile.hasPin) ...[
              const Text('Current PIN'),
              const SizedBox(height: 6),
              TextField(
                controller: _current,
                keyboardType: TextInputType.number,
                obscureText: _obscureCurrent,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 8,
                decoration: InputDecoration(
                  hintText: 'Current PIN',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrent
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscureCurrent = !_obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
            const Text('New PIN'),
            const SizedBox(height: 6),
            TextField(
              controller: _newPin,
              keyboardType: TextInputType.number,
              obscureText: _obscureNew,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 8,
              autofocus: !widget.profile.hasPin,
              decoration: InputDecoration(
                hintText: '4–8 digits',
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureNew ? Icons.visibility : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Confirm PIN'),
            const SizedBox(height: 6),
            TextField(
              controller: _confirm,
              keyboardType: TextInputType.number,
              obscureText: _obscureConfirm,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 8,
              decoration: InputDecoration(
                hintText: 'Repeat new PIN',
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.profile.hasPin && !widget.blockPinRemoval)
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: _remove,
            child: const Text('Remove PIN'),
          ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Emoji picker
// ---------------------------------------------------------------------------

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({required this.selected, required this.onSelected});

  final String selected;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: Profile.avatarOptions.map((emoji) {
        final isSelected = emoji == selected;
        return GestureDetector(
          onTap: () => onSelected(emoji),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
        );
      }).toList(),
    );
  }
}
