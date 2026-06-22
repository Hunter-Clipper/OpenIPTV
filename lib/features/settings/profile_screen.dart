import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/shared/widgets/info_tooltip.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(allProfilesProvider);
    final activeProfile = ref.watch(activeProfileProvider).valueOrNull;
    final tooltipController = InfoTooltipController();

    return InfoTooltipScope(
      controller: tooltipController,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profiles'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New Profile',
              onPressed: () => _showCreateDialog(context, ref),
            ),
          ],
        ),
        body: profilesAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const Center(child: Text("Couldn't load profiles.")),
          data: (profiles) {
            if (profiles.isEmpty) {
              return _EmptyState(
                onAdd: () => _showCreateDialog(context, ref),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: profiles.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final p = profiles[i];
                final isActive = activeProfile?.id == p.id;
                return _ProfileTile(
                  profile: p,
                  isActive: isActive,
                  onSwitch: () =>
                      _switchToProfile(context, ref, p),
                  onEdit: () =>
                      _showEditDialog(context, ref, p),
                  onPin: () => _showPinDialog(context, ref, p),
                  onDelete: () =>
                      _confirmDelete(context, ref, p),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(
      BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (ctx) => _CreateProfileDialog(ref: ref),
    );
    ref.invalidate(allProfilesProvider);
  }

  Future<void> _showEditDialog(
      BuildContext context, WidgetRef ref, Profile profile) async {
    await showDialog(
      context: context,
      builder: (ctx) =>
          _EditProfileDialog(profile: profile, ref: ref),
    );
    ref.invalidate(allProfilesProvider);
  }

  Future<void> _switchToProfile(
      BuildContext context, WidgetRef ref, Profile profile) async {
    if (!profile.hasPin) {
      await ref.read(profileServiceProvider).switchToProfile(profile.id);
      ref.invalidate(activeProfileProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Switched to ${profile.name}'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    // Profile has a PIN.
    final pin = await _promptPin(context, label: 'Enter PIN for ${profile.name}');
    if (pin == null || !context.mounted) return;
    final ok = await ref
        .read(profileServiceProvider)
        .switchToProfile(profile.id, pin: pin);
    ref.invalidate(activeProfileProvider);
    if (context.mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Switched to ${profile.name}'),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "That PIN doesn't seem right. Try again."),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _showPinDialog(
      BuildContext context, WidgetRef ref, Profile profile) async {
    await showDialog(
      context: context,
      builder: (ctx) => _PinManagementDialog(profile: profile, ref: ref),
    );
    ref.invalidate(allProfilesProvider);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Profile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Profile?'),
        content: Text(
          'Deleting "${profile.name}" will remove all its favourites and settings. '
          'Your sources and channels are not deleted.',
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
    await ref.read(profileServiceProvider).deleteProfile(profile.id);
    ref.invalidate(allProfilesProvider);
    ref.invalidate(activeProfileProvider);
  }

  Future<String?> _promptPin(BuildContext context,
      {required String label}) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          decoration: const InputDecoration(hintText: 'Enter PIN'),
          autofocus: true,
          onSubmitted: (_) =>
              Navigator.of(ctx).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile tile
// ---------------------------------------------------------------------------

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.onSwitch,
    required this.onEdit,
    required this.onPin,
    required this.onDelete,
  });

  final Profile profile;
  final bool isActive;
  final VoidCallback onSwitch;
  final VoidCallback onEdit;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                      color: theme.scaffoldBackgroundColor,
                      width: 1.5),
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
          if (isActive && profile.hasPin)
            const Text(' · '),
          if (profile.hasPin)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 2),
                Text('PIN set',
                    style: theme.textTheme.bodySmall),
              ],
            ),
        ],
      ),
      trailing: PopupMenuButton<_ProfileAction>(
        onSelected: (action) {
          switch (action) {
            case _ProfileAction.switchTo:
              onSwitch();
            case _ProfileAction.edit:
              onEdit();
            case _ProfileAction.pin:
              onPin();
            case _ProfileAction.delete:
              onDelete();
          }
        },
        itemBuilder: (_) => [
          if (!isActive)
            const PopupMenuItem(
              value: _ProfileAction.switchTo,
              child: Text('Switch to this profile'),
            ),
          const PopupMenuItem(
            value: _ProfileAction.edit,
            child: Text('Edit'),
          ),
          PopupMenuItem(
            value: _ProfileAction.pin,
            child: Text(
                profile.hasPin ? 'Change or remove PIN' : 'Set PIN'),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: _ProfileAction.delete,
            child: Text('Delete'),
          ),
        ],
      ),
      onTap: isActive ? null : onSwitch,
    );
  }
}

enum _ProfileAction { switchTo, edit, pin, delete }

// ---------------------------------------------------------------------------
// Create profile dialog
// ---------------------------------------------------------------------------

class _CreateProfileDialog extends StatefulWidget {
  const _CreateProfileDialog({required this.ref});

  final WidgetRef ref;

  @override
  State<_CreateProfileDialog> createState() =>
      _CreateProfileDialogState();
}

class _CreateProfileDialogState extends State<_CreateProfileDialog> {
  final _nameController = TextEditingController();
  String _selectedEmoji = Profile.avatarOptions.first;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    try {
      await widget.ref
          .read(profileServiceProvider)
          .createProfile(name: name, avatarEmoji: _selectedEmoji);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString().contains('Maximum')
            ? "You've reached the maximum number of profiles (10)."
            : "Couldn't create the profile. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tooltipController = InfoTooltipController();
    return InfoTooltipScope(
      controller: tooltipController,
      child: AlertDialog(
        title: const Text('New Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoTooltip(
                id: 'create_profile_name',
                title: 'Profile Name',
                body:
                    'A name to identify this profile. For example: "Kids", '
                    '"Living Room", or your own name.',
                child: const Text('Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'e.g. Kids, Living Room'),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _create(),
              ),
              const SizedBox(height: 16),
              InfoTooltip(
                id: 'create_profile_avatar',
                title: 'Avatar',
                body:
                    'Choose an emoji to represent this profile. '
                    "It'll appear when switching between profiles.",
                child: const Text('Avatar'),
              ),
              const SizedBox(height: 8),
              _EmojiPicker(
                selected: _selectedEmoji,
                onSelected: (e) =>
                    setState(() => _selectedEmoji = e),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _create,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit profile dialog
// ---------------------------------------------------------------------------

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog(
      {required this.profile, required this.ref});

  final Profile profile;
  final WidgetRef ref;

  @override
  State<_EditProfileDialog> createState() =>
      _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late String _selectedEmoji;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.profile.name);
    _selectedEmoji = widget.profile.avatarEmoji;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    try {
      await widget.ref.read(profileServiceProvider).updateProfile(
            widget.profile.copyWith(
                name: name, avatarEmoji: _selectedEmoji),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() =>
          _error = "Couldn't save changes. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final tooltipController = InfoTooltipController();
    return InfoTooltipScope(
      controller: tooltipController,
      child: AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              InfoTooltip(
                id: 'edit_profile_avatar',
                title: 'Avatar',
                body:
                    'The emoji shown next to this profile when switching.',
                child: const Text('Avatar'),
              ),
              const SizedBox(height: 8),
              _EmojiPicker(
                selected: _selectedEmoji,
                onSelected: (e) =>
                    setState(() => _selectedEmoji = e),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13),
                ),
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PIN management dialog
// ---------------------------------------------------------------------------

class _PinManagementDialog extends StatefulWidget {
  const _PinManagementDialog(
      {required this.profile, required this.ref});

  final Profile profile;
  final WidgetRef ref;

  @override
  State<_PinManagementDialog> createState() =>
      _PinManagementDialogState();
}

class _PinManagementDialogState
    extends State<_PinManagementDialog> {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  String? _error;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPin = _newPinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (newPin != confirm) {
      setState(() => _error = "The PINs don't match. Try again.");
      return;
    }
    if (newPin.length < 4) {
      setState(
          () => _error = 'PIN must be at least 4 digits.');
      return;
    }

    if (widget.profile.hasPin) {
      // Verify current PIN first.
      final current = _currentPinController.text.trim();
      final ok = widget.ref
          .read(profileServiceProvider)
          .verifyPin(widget.profile, current);
      if (!ok) {
        setState(() =>
            _error = 'Your current PIN is incorrect. Try again.');
        return;
      }
    }

    await widget.ref
        .read(profileServiceProvider)
        .setPin(widget.profile.id, newPin);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _removePinPressed() async {
    final current = _currentPinController.text.trim();
    try {
      await widget.ref
          .read(profileServiceProvider)
          .clearPin(widget.profile.id, currentPin: current);
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError {
      setState(() =>
          _error = 'Your current PIN is incorrect. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tooltipController = InfoTooltipController();
    return InfoTooltipScope(
      controller: tooltipController,
      child: AlertDialog(
        title: Text(
            widget.profile.hasPin ? 'Change PIN' : 'Set PIN'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoTooltip(
                id: 'profile_pin_info',
                title: 'Profile PIN',
                body:
                    'A PIN protects this profile so only people who know '
                    'it can switch to it or import backups. '
                    "It doesn't protect your streams or account — "
                    "it's just for switching profiles.",
                child: Text(
                    widget.profile.hasPin
                        ? 'Change or remove your PIN.'
                        : 'Set a 4–8 digit PIN to protect this profile.'),
              ),
              const SizedBox(height: 16),
              if (widget.profile.hasPin) ...[
                const Text('Current PIN'),
                const SizedBox(height: 6),
                TextField(
                  controller: _currentPinController,
                  keyboardType: TextInputType.number,
                  obscureText: _obscureCurrent,
                  maxLength: 8,
                  decoration: InputDecoration(
                    hintText: 'Current PIN',
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrent
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () => setState(
                          () => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              const Text('New PIN'),
              const SizedBox(height: 6),
              TextField(
                controller: _newPinController,
                keyboardType: TextInputType.number,
                obscureText: _obscureNew,
                maxLength: 8,
                decoration: InputDecoration(
                  hintText: 'New PIN (4–8 digits)',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Confirm New PIN'),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: _obscureConfirm,
                maxLength: 8,
                decoration: InputDecoration(
                  hintText: 'Repeat new PIN',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () => setState(
                        () => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                onSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (widget.profile.hasPin)
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor:
                      Theme.of(context).colorScheme.error),
              onPressed: _removePinPressed,
              child: const Text('Remove PIN'),
            ),
          FilledButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Emoji picker
// ---------------------------------------------------------------------------

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({
    required this.selected,
    required this.onSelected,
  });

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
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.2)
                  : Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Center(
              child: Text(emoji,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👤', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'No profiles yet.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a profile to keep your favourites and settings separate.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create Profile'),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
