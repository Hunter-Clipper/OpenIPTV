import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/auto_refresh_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/backup_manager.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/widgets/info_tooltip.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tooltipController = InfoTooltipController();

    return InfoTooltipScope(
      controller: tooltipController,
      child: Scaffold(
        appBar: AppBar(title: const Text('Backup & Restore')),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // --------------- EXPORT ---------------
            InfoTooltip(
              id: 'backup_export_section',
              title: 'Export Backup',
              body: 'Exporting saves every profile, every source, and your '
                  'app settings into a single .zip file. You can optionally '
                  'protect it with a password.',
              tip: "Save this file somewhere safe — you'll need it to "
                  'restore everything on a new device.',
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
              title: const Text('Export Backup'),
              subtitle: const Text(
                'Save all profiles, sources, and settings as a .zip file',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exportBackup(context, ref),
            ),

            // --------------- IMPORT ---------------
            const SizedBox(height: 16),
            InfoTooltip(
              id: 'backup_import_section',
              title: 'Restore Backup',
              body: 'Importing reads a .zip backup file and adds its '
                  'profiles and sources to this device. '
                  "If the backup was password-protected, you'll be asked "
                  'for the password used when it was exported.',
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
              title: const Text('Import Backup'),
              subtitle: const Text('Open a .zip backup file'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _importBackup(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final password = await _promptSetPassword(context);
    if (password == null) return; // dialog dismissed — cancel entirely.
    if (!context.mounted) return;

    try {
      _showLoadingSnack(context, 'Preparing backup…');
      final db = ref.read(appDatabaseProvider);
      final prefs = await ref.read(appPreferencesProvider.future);
      final manager = BackupManager(db: db, prefs: prefs);
      final bytes =
          await manager.exportAll(password: password.isEmpty ? null : password);

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final file = File('${tempDir.path}/OpenIPTV_Backup_$stamp.zip');
      await file.writeAsBytes(bytes);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          subject: 'OpenIPTV backup',
        ),
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

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
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

    if (!context.mounted) return;
    await _doImport(context, ref, result.files.first.bytes!);
  }

  Future<void> _doImport(
    BuildContext context,
    WidgetRef ref,
    Uint8List bytes, {
    String? password,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final prefs = await ref.read(appPreferencesProvider.future);
    final manager = BackupManager(db: db, prefs: prefs);

    try {
      final summary = await manager.importAll(bytes, password: password);
      await _afterImport(ref);
      if (!context.mounted) return;
      _showSuccess(
        context,
        'Restored ${summary.profileCount} '
        'profile${summary.profileCount == 1 ? '' : 's'} and '
        '${summary.sourceCount} '
        'source${summary.sourceCount == 1 ? '' : 's'}.',
      );
    } on BackupException catch (e) {
      if (e.message == 'password_required') {
        if (!context.mounted) return;
        final pw = await _promptEnterPassword(context);
        if (pw == null || !context.mounted) return;
        await _doImport(context, ref, bytes, password: pw);
      } else {
        if (!context.mounted) return;
        _showError(context, e.message);
      }
    } catch (_) {
      if (!context.mounted) return;
      _showError(context,
          "Couldn't open this backup file. "
          "Make sure it's a valid OpenIPTV backup.");
    }
  }

  /// Backup-affected state doesn't live behind reactive providers everywhere
  /// — sources and app-level settings are one-shot reads seeded once, so an
  /// import has to explicitly push the fresh data through or the UI keeps
  /// showing what was there before the restore until the app is relaunched.
  Future<void> _afterImport(WidgetRef ref) async {
    ref.invalidate(allSourcesProvider);
    ref.invalidate(appPreferencesProvider);
    final prefs = await ref.read(appPreferencesProvider.future);
    syncSettingsProviders(ref, prefs);
    unawaited(syncAutoRefreshRegistration(prefs));
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  /// Returns '' for "no password", the entered password, or null if the
  /// user dismissed the dialog (export should be cancelled entirely).
  Future<String?> _promptSetPassword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Protect This Backup?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Source credentials are stored in plain text inside the '
              'backup file. Optionally set a password to encrypt it — '
              "you'll need the same password to restore it.",
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration:
                  const InputDecoration(hintText: 'Password (optional)'),
              onSubmitted: (_) => Navigator.of(ctx).pop(controller.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(''),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptEnterPassword(BuildContext context) {
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
              'This backup was protected with a password. '
              'Enter the password that was set when it was exported.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Enter password'),
              onSubmitted: (_) => Navigator.of(ctx).pop(controller.text),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Feedback
  // ---------------------------------------------------------------------------

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
