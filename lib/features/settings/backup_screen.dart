import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/auto_refresh_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/backup_manager.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/shared/utils/format.dart';
import 'package:open_iptv/shared/widgets/info_tooltip.dart';
import 'package:open_iptv/shared/widgets/section_header.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

/// Lets the user pick a backup file and restores it — shared by Settings →
/// Backup & Restore and the setup wizard's "Restore from a backup" (fresh
/// installs). Shows its own error messages; returns what was restored, or
/// null if cancelled / failed.
Future<BackupSummary?> restoreBackupFromFile(
        BuildContext context, WidgetRef ref) =>
    const BackupScreen()._pickAndRestore(context, ref);

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
            const InfoTooltip(
              id: 'backup_export_section',
              title: 'Export Backup',
              body: 'Exporting saves every profile, every source, and your '
                  'app settings into a single .zip file. You can optionally '
                  'protect it with a password.',
              tip: "Save this file somewhere safe — you'll need it to "
                  'restore everything on a new device.',
              child: SectionHeader(
                'Export',
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              ),
            ),
            const Divider(height: 1),
            TvActivatable(
              autofocus: true,
              onTap: () => _exportBackup(context, ref),
              builder: (onTap) => ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Export Backup'),
                subtitle: const Text(
                  'Save all profiles, sources, and settings as a .zip file',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: onTap,
              ),
            ),

            // --------------- IMPORT ---------------
            const SizedBox(height: 16),
            const InfoTooltip(
              id: 'backup_import_section',
              title: 'Restore Backup',
              body: 'Importing reads a .zip backup file and adds its '
                  'profiles and sources to this device. '
                  "If the backup was password-protected, you'll be asked "
                  'for the password used when it was exported.',
              tip: 'Importing does not delete anything — your existing '
                  'profiles are kept.',
              child: SectionHeader(
                'Restore',
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              ),
            ),
            const Divider(height: 1),
            TvActivatable(
              onTap: () => _importBackup(context, ref),
              builder: (onTap) => ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Import Backup'),
                subtitle: const Text('Open a .zip backup file'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onTap,
              ),
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

      final stamp = formatYmd(DateTime.now());
      final name = 'OpenIPTV_Backup_$stamp.zip';

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // TVs usually have no share targets at all, so saving to the device
      // is the only option there.
      final destination = PlatformHelper.isTV(context)
          ? _ExportDestination.downloads
          : await _chooseDestination(context);
      if (destination == null || !context.mounted) return;

      if (destination == _ExportDestination.downloads) {
        final location = await _saveToDownloads(name, bytes);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup saved to $location')),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$name');
      await file.writeAsBytes(bytes);
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

  Future<_ExportDestination?> _chooseDestination(BuildContext context) {
    return showDialog<_ExportDestination>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Backup'),
        content: const Text(
            'Save the backup file to this device, or share it to another '
            'app (email, cloud storage, …).'),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(_ExportDestination.share),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: const Text('Share…')),
          ),
          TvActivatable(
            autofocus: true,
            onTap: () => Navigator.of(ctx).pop(_ExportDestination.downloads),
            builder: (onTap) => FilledButton(
                onPressed: onTap, child: const Text('Save to Downloads')),
          ),
        ],
      ),
    );
  }

  /// Writes to the public Downloads folder via the native side (MediaStore
  /// on Android 10+; older versions need the storage permission first).
  Future<String> _saveToDownloads(String name, Uint8List bytes) async {
    const channel = MethodChannel('openiptv/files');
    Future<String> save() async =>
        await channel.invokeMethod<String>('saveToDownloads', {
          'name': name,
          'bytes': bytes,
          'mimeType': 'application/zip',
        }) ??
        'Downloads/$name';
    try {
      return await save();
    } on PlatformException {
      // Android 9 and below: ask for storage access, then retry once.
      if (await Permission.storage.request().isGranted) return save();
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final summary = await _pickAndRestore(context, ref);
    if (summary == null || !context.mounted) return;
    _showSuccess(
      context,
      'Restored ${summary.profileCount} '
      'profile${summary.profileCount == 1 ? '' : 's'} and '
      '${summary.sourceCount} '
      'source${summary.sourceCount == 1 ? '' : 's'}.',
    );
  }

  Future<BackupSummary?> _pickAndRestore(
      BuildContext context, WidgetRef ref) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
    } catch (_) {
      if (!context.mounted) return null;
      _showError(context,
          "Couldn't open the file picker. Check that the app has file "
          'access permission and try again.');
      return null;
    }

    if (result == null ||
        result.files.isEmpty ||
        result.files.first.bytes == null) {
      return null;
    }

    if (!context.mounted) return null;
    return _doImport(context, ref, result.files.first.bytes!);
  }

  Future<BackupSummary?> _doImport(
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
      return summary;
    } on BackupException catch (e) {
      if (e.message == 'password_required') {
        if (!context.mounted) return null;
        final pw = await _promptEnterPassword(context);
        if (pw == null || !context.mounted) return null;
        return _doImport(context, ref, bytes, password: pw);
      }
      if (context.mounted) _showError(context, e.message);
      return null;
    } catch (_) {
      if (!context.mounted) return null;
      _showError(context,
          "Couldn't open this backup file. "
          "Make sure it's a valid OpenIPTV backup.");
      return null;
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
              decoration:
                  const InputDecoration(hintText: 'Password (optional)'),
              onSubmitted: (_) => Navigator.of(ctx).pop(controller.text),
            ),
          ],
        ),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(''),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: const Text('Skip')),
          ),
          TvActivatable(
            // A plain autofocus TextField above this would otherwise trap
            // D-pad focus permanently: Flutter's EditableText consumes
            // vertical arrow keys for its own (single-line, no-op) caret
            // movement, so DirectionalFocusIntent never bubbles up to move
            // focus onto Skip/Export. Landing here by default keeps the
            // dialog fully navigable; typing a password still works by
            // pressing up into the field first.
            autofocus: true,
            onTap: () => Navigator.of(ctx).pop(controller.text),
            builder: (onTap) =>
                FilledButton(onPressed: onTap, child: const Text('Export')),
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
              decoration: const InputDecoration(hintText: 'Enter password'),
              onSubmitted: (_) => Navigator.of(ctx).pop(controller.text),
            ),
          ],
        ),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(null),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: const Text('Cancel')),
          ),
          TvActivatable(
            // See the matching comment in _promptSetPassword: autofocusing
            // the TextField instead would trap D-pad focus there permanently.
            autofocus: true,
            onTap: () => Navigator.of(ctx).pop(controller.text),
            builder: (onTap) =>
                FilledButton(onPressed: onTap, child: const Text('Restore')),
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

enum _ExportDestination { downloads, share }
