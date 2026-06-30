import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/profile.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/backup_manager.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:open_iptv/shared/widgets/info_tooltip.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tooltipController = InfoTooltipController();
    final profileAsync = ref.watch(activeProfileProvider);

    return InfoTooltipScope(
      controller: tooltipController,
      child: Scaffold(
        appBar: AppBar(title: const Text('Backup & Restore')),
        body: profileAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
              child: Text("Couldn't load profile information.")),
          data: (profile) => ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              // --------------- EXPORT ---------------
              InfoTooltip(
                id: 'backup_export_section',
                title: 'Export Profile',
                body:
                    'Exporting saves your profile settings, favourites, '
                    'and source list into a single .iptvprofile file. '
                    'If your profile has a PIN, the file will be encrypted '
                    'with that PIN automatically.',
                tip: "Save this file somewhere safe — you'll need it to "
                    'restore your settings on a new device.',
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Export',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Export Profile'),
                subtitle: profile != null
                    ? Text(
                        'Save "${profile.name}" as a .iptvprofile file',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : const Text('No active profile'),
                enabled: profile != null,
                trailing: const Icon(Icons.chevron_right),
                onTap: profile == null
                    ? null
                    : () => _exportProfile(context, ref, profile),
              ),

              // --------------- IMPORT ---------------
              const SizedBox(height: 16),
              InfoTooltip(
                id: 'backup_import_section',
                title: 'Restore Profile',
                body:
                    'Importing reads a .iptvprofile file and adds the profile '
                    'and its sources to this device. '
                    "If the backup was encrypted, you'll be asked for the PIN "
                    'that was set on the original profile.',
                tip: 'Importing does not delete anything — your existing '
                    'profiles are kept.',
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Restore',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Import Profile'),
                subtitle: Text(
                  'Open a .iptvprofile backup file',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importProfile(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _exportProfile(
    BuildContext context,
    WidgetRef ref,
    Profile profile,
  ) async {
    try {
      _showLoadingSnack(context, 'Preparing backup…');
      final db = ref.read(appDatabaseProvider);
      final manager = BackupManager(db: db);
      final bytes = await manager.exportProfile(profile);

      // Save to a temp file then share.
      final tempDir = await getTemporaryDirectory();
      final fileName =
          '${profile.name.replaceAll(RegExp(r'\s+'), '_')}.iptvprofile';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/zip')],
        subject: 'OpenIPTV profile backup',
      );
    } catch (e) {
      if (!context.mounted) return;
      _showError(context,
          "Couldn't create the backup file. Make sure you have storage "
          'permission and try again.');
    }
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  Future<void> _importProfile(BuildContext context, WidgetRef ref) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
    } catch (_) {
      if (!context.mounted) return;
      _showError(context,
          "Couldn't open the file picker. Check that the app has file "
          'access permission and try again.');
      return;
    }

    if (result == null ||
        result.files.isEmpty ||
        result.files.first.bytes == null) {
      return;
    }

    final bytes = result.files.first.bytes!;
    final fileName = result.files.first.name;

    if (!fileName.endsWith('.iptvprofile')) {
      if (!context.mounted) return;
      _showError(context,
          "Couldn't open this backup file. "
          "Make sure it's a valid .iptvprofile file.");
      return;
    }

    await _doImport(context, ref, bytes);
  }

  Future<void> _doImport(
    BuildContext context,
    WidgetRef ref,
    Uint8List bytes,
  ) async {
    final db = ref.read(appDatabaseProvider);
    final manager = BackupManager(db: db);

    try {
      // First attempt without a PIN.
      final profile = await manager.importProfile(bytes);
      ref.invalidate(allProfilesProvider);
      if (!context.mounted) return;
      _showSuccess(context, 'Profile "${profile.name}" restored.');
    } on BackupException catch (e) {
      if (e.message == 'pin_required') {
        // Prompt for PIN.
        if (!context.mounted) return;
        final pin = await _promptPin(context);
        if (pin == null || !context.mounted) return;
        try {
          final profile = await manager.importProfile(bytes, pin: pin);
          ref.invalidate(allProfilesProvider);
          if (!context.mounted) return;
          _showSuccess(context, 'Profile "${profile.name}" restored.');
        } on BackupException catch (e2) {
          if (!context.mounted) return;
          _showError(context, e2.message);
        }
      } else {
        _showError(context, e.message);
      }
    } catch (_) {
      if (!context.mounted) return;
      _showError(context,
          "Couldn't open this backup file. "
          "Make sure it's a valid .iptvprofile file.");
    }
  }

  Future<String?> _promptPin(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup is Protected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This backup was created with a PIN. '
              'Enter the PIN that was set on the original profile.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 8,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Enter PIN'),
              onSubmitted: (_) =>
                  Navigator.of(ctx).pop(controller.text.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showLoadingSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        duration: const Duration(seconds: 30),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
