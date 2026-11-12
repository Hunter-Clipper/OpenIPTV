import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/auto_refresh_service.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/core/storage/backup_manager.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/utils/format.dart';
import 'package:open_iptv/shared/widgets/info_tooltip.dart';
import 'package:open_iptv/shared/widgets/device_file_picker.dart';
import 'package:open_iptv/shared/widgets/settings_group.dart';
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
    final l10n = AppLocalizations.of(context);

    return InfoTooltipScope(
      controller: tooltipController,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.backupTitle)),
        body: TvFollowFocus(
            focusFirst: true,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                SettingsGroup(
                  title: l10n.backupExportGroup,
                  children: [
                    InfoTooltip(
                      id: 'backup_export_section',
                      title: l10n.backupExportInfoTitle,
                      body: l10n.backupExportInfoBody,
                      tip: l10n.backupExportInfoTip,
                      child: TvActivatable(
                        autofocus: true,
                        onTap: () => _exportBackup(context, ref),
                        builder: (onTap) => ListTile(
                          leading:
                              const IconBadge(icon: Icons.upload_file_outlined),
                          title: Text(l10n.backupExportTitle),
                          subtitle: Text(
                            l10n.backupExportSubtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: onTap,
                        ),
                      ),
                    ),
                  ],
                ),
                SettingsGroup(
                  title: l10n.backupRestoreGroup,
                  children: [
                    InfoTooltip(
                      id: 'backup_import_section',
                      title: l10n.backupImportInfoTitle,
                      body: l10n.backupImportInfoBody,
                      tip: l10n.backupImportInfoTip,
                      child: TvActivatable(
                        onTap: () => _importBackup(context, ref),
                        builder: (onTap) => ListTile(
                          leading:
                              const IconBadge(icon: Icons.download_outlined),
                          title: Text(l10n.backupImportTitle),
                          subtitle: Text(l10n.backupImportSubtitle,
                              style: Theme.of(context).textTheme.bodySmall),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: onTap,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final password = await _promptSetPassword(context);
    if (password == null) return; // dialog dismissed — cancel entirely.
    if (!context.mounted) return;

    try {
      _showLoadingSnack(context, l10n.backupPreparing);
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
          SnackBar(content: Text(l10n.backupSavedTo(location))),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$name');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          subject: l10n.backupShareSubject,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, l10n.backupCreateFailed);
    }
  }

  Future<_ExportDestination?> _chooseDestination(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return showDialog<_ExportDestination>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupSaveTitle),
        content: Text(l10n.backupSaveBody),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(_ExportDestination.share),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: Text(l10n.backupShareButton)),
          ),
          TvActivatable(
            autofocus: true,
            onTap: () => Navigator.of(ctx).pop(_ExportDestination.downloads),
            builder: (onTap) => FilledButton(
                onPressed: onTap, child: Text(l10n.backupSaveToDownloads)),
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
    final l10n = AppLocalizations.of(context);
    _showSuccess(
      context,
      l10n.backupRestored(l10n.backupRestoredProfiles(summary.profileCount),
          l10n.backupRestoredSources(summary.sourceCount)),
    );
  }

  Future<BackupSummary?> _pickAndRestore(
      BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    PickedDeviceFile? file;
    try {
      file = await pickDeviceFile(context,
          title: l10n.backupPickTitle, extensions: const ['.zip']);
    } catch (_) {
      if (!context.mounted) return null;
      _showError(context, l10n.backupPickerFailed);
      return null;
    }

    if (file == null || !context.mounted) return null;
    return _doImport(context, ref, file.bytes);
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
      _showError(context, AppLocalizations.of(context).backupOpenFailed);
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
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupProtectTitle),
        // Scrolls when the TV keyboard leaves little room.
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.backupProtectBody),
            const SizedBox(height: 16),
            TvTextFieldGate(
                // TV: the remote starts on the password (OK types one), not on
                // Export — one press used to export an unprotected backup.
                autofocus: true,
                builder: (context, fieldNode) => TextField(
                      focusNode: fieldNode,
                      controller: controller,
                      obscureText: true,
                      decoration: InputDecoration(
                          hintText: l10n.backupPasswordOptionalHint),
                      onSubmitted: (_) =>
                          Navigator.of(ctx).pop(controller.text),
                    )),
          ],
        ),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(''),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: Text(l10n.backupSkip)),
          ),
          TvActivatable(
            // Phones: the default button (a plain autofocus TextField would
            // pop the keyboard for an optional password). TV starts on the
            // field above.
            autofocus: !PlatformHelper.isTV(ctx),
            onTap: () => Navigator.of(ctx).pop(controller.text),
            builder: (onTap) =>
                FilledButton(onPressed: onTap, child: Text(l10n.backupExportButton)),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptEnterPassword(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupProtectedTitle),
        // Scrolls when the TV keyboard leaves little room.
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.backupProtectedBody),
            const SizedBox(height: 16),
            TvTextFieldGate(
                // TV: the password is required, so the keyboard opens at once.
                openOnShow: true,
                builder: (context, fieldNode) => TextField(
                      focusNode: fieldNode,
                      controller: controller,
                      obscureText: true,
                      decoration: InputDecoration(
                          hintText: l10n.backupEnterPasswordHint),
                      onSubmitted: (_) =>
                          Navigator.of(ctx).pop(controller.text),
                    )),
          ],
        ),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(null),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: Text(l10n.commonCancel)),
          ),
          TvActivatable(
            // Phones: the default button. TV opens the field's keyboard.
            autofocus: !PlatformHelper.isTV(ctx),
            onTap: () => Navigator.of(ctx).pop(controller.text),
            builder: (onTap) =>
                FilledButton(onPressed: onTap, child: Text(l10n.backupRestoreButton)),
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
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
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
