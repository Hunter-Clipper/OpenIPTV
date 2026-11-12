import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/shared/utils/motion.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/update_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/updates/release_notes.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

// When the last automatic check ran (this process). Android keeps the app
// alive in the background, so "opening" it from the home screen is often a
// resume, not a fresh start: the check also runs on resume, at most every
// [_recheckAfter] (and never twice at once).
DateTime? _lastAutoCheck;
bool _autoCheckRunning = false;
const _recheckAfter = Duration(
    seconds: int.fromEnvironment('OPENIPTV_UPDATE_RECHECK_SECONDS',
        defaultValue: 15 * 60));

/// Automatic check, on launch and when the app comes back to the
/// foreground: offers a newer release. Only for admin profiles (installing
/// replaces the app for every profile on the device), never for Play Store
/// installs, never for a version the user chose to skip, and never over a
/// video that's playing ([busy]) — the next time the app is opened checks
/// again.
Future<void> maybePromptForUpdate(BuildContext context,
    {bool Function()? busy}) async {
  final last = _lastAutoCheck;
  if (_autoCheckRunning ||
      (last != null && DateTime.now().difference(last) < _recheckAfter)) {
    return;
  }
  if (busy?.call() ?? false) return;
  _autoCheckRunning = true;
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    final service = container.read(updateServiceProvider);
    final prefs = await container.read(appPreferencesProvider.future);
    if (!prefs.autoUpdateCheck) return;
    if (!await service.isSelfUpdatable()) return;
    final profile = await container.read(activeProfileProvider.future);
    // Not marked as checked: if a kid profile is in use, switching to an
    // admin profile still gets the check.
    if (profile?.isAdmin != true) return;

    _lastAutoCheck = DateTime.now();
    final update = await service.checkForUpdate();
    await prefs.setLastUpdateCheck(DateTime.now());
    if (update == null) return;
    if (prefs.skippedUpdateVersion == update.version.toString()) return;
    if (!context.mounted || (busy?.call() ?? false)) {
      // Started watching meanwhile: offer it next time instead.
      _lastAutoCheck = null;
      return;
    }
    await showUpdateDialog(context, update);
  } finally {
    _autoCheckRunning = false;
  }
}

/// Settings → "Check for updates": always checks now and reports the result.
Future<void> checkForUpdateManually(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final service = container.read(updateServiceProvider);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  void say(String text) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  if (!await service.isSelfUpdatable()) {
    say(l10n.updateManagedByPlay);
    return;
  }
  say(l10n.updateChecking);
  final (latest, installed) =
      await (service.fetchLatest(), service.installedVersion()).wait;
  final prefs = await container.read(appPreferencesProvider.future);
  await prefs.setLastUpdateCheck(DateTime.now());
  if (latest == null || installed == null) {
    say(l10n.updateCheckFailed);
    return;
  }
  if (!(latest.version > installed)) {
    say(l10n.updateUpToDate('$installed'));
    return;
  }
  messenger.hideCurrentSnackBar();
  if (context.mounted) await showUpdateDialog(context, latest, manual: true);
}

Future<void> showUpdateDialog(BuildContext context, UpdateInfo update,
    {bool manual = false}) {
  return showDialog<void>(
    context: context,
    // Mid-download dismissal would orphan the download; the dialog's own
    // buttons handle closing.
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(update: update, manual: manual),
  );
}

enum _Phase { offer, needsPermission, downloading, handedOff, failed }

class _UpdateDialog extends ConsumerStatefulWidget {
  const _UpdateDialog({required this.update, required this.manual});

  final UpdateInfo update;
  final bool manual;

  @override
  ConsumerState<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<_UpdateDialog>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.offer;
  double? _progress;
  String? _installedVersion;
  File? _apk;

  UpdateService get _service => ref.read(updateServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.installedVersion().then((v) {
      if (mounted && v != null) setState(() => _installedVersion = '$v');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the "Install unknown apps" settings screen: carry on
  // automatically once the permission has been granted.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _phase == _Phase.needsPermission) {
      _start();
    }
  }

  Future<void> _start() async {
    if (!await _service.canInstallPackages()) {
      if (mounted) setState(() => _phase = _Phase.needsPermission);
      return;
    }
    if (_apk != null && _apk!.existsSync()) {
      await _install(_apk!);
      return;
    }
    setState(() {
      _phase = _Phase.downloading;
      _progress = null;
    });
    try {
      final apk = await _service.download(widget.update, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      _apk = apk;
      await _install(apk);
    } catch (e) {
      debugPrint('[OTV-update] download/install failed: $e');
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _install(File apk) async {
    await _service.install(apk);
    if (mounted) setState(() => _phase = _Phase.handedOff);
  }

  Future<void> _skip() async {
    final prefs = await ref.read(appPreferencesProvider.future);
    await prefs.setSkippedUpdateVersion(widget.update.version.toString());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final update = widget.update;
    final from = _installedVersion;
    final l10n = AppLocalizations.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.system_update_rounded,
                        color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.updateAvailableTitle,
                            style: theme.textTheme.titleLarge!
                                .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          from == null
                              ? l10n.updateVersion('${update.version}')
                              : l10n.updateVersionFromTo(
                                  from, '${update.version}'),
                          style: theme.textTheme.bodyMedium!.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(child: _body(theme)),
              const SizedBox(height: 16),
              _actions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    switch (_phase) {
      case _Phase.offer:
        return _NotesBox(
          title: widget.update.title,
          notes: widget.update.notes,
        );
      case _Phase.needsPermission:
        return Text(
          l10n.updatePermissionBody,
          style: theme.textTheme.bodyMedium,
        );
      case _Phase.downloading:
        final pct = _progress == null ? null : (_progress! * 100).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                pct == null
                    ? l10n.updateDownloading
                    : l10n.updateDownloadingPercent(pct),
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: _progress, minHeight: 6),
            ),
          ],
        );
      case _Phase.handedOff:
        return Text(
          l10n.updateHandedOffBody,
          style: theme.textTheme.bodyMedium,
        );
      case _Phase.failed:
        return Text(
          l10n.updateFailedBody,
          style: theme.textTheme.bodyMedium,
        );
    }
  }

  Widget _actions() {
    final l10n = AppLocalizations.of(context);
    Widget button(String label, VoidCallback onTap,
        {bool primary = false, bool autofocus = false}) {
      return TvActivatable(
        autofocus: autofocus,
        onTap: onTap,
        builder: (tap) => primary
            ? FilledButton(onPressed: tap, child: Text(label))
            : TextButton(onPressed: tap, child: Text(label)),
      );
    }

    void close() => Navigator.of(context).pop();
    final buttons = switch (_phase) {
      _Phase.offer => [
          if (!widget.manual) button(l10n.updateSkipVersion, _skip),
          button(l10n.updateLater, close),
          button(l10n.updateNow, _start, primary: true, autofocus: true),
        ],
      _Phase.needsPermission => [
          button(l10n.commonCancel, close),
          button(l10n.updateOpenSettings, _service.openInstallPermissionSettings,
              primary: true, autofocus: true),
        ],
      _Phase.downloading => <Widget>[],
      _Phase.handedOff => [
          button(l10n.updateClose, close),
          button(l10n.updateInstallAgain, _start, primary: true, autofocus: true),
        ],
      _Phase.failed => [
          button(l10n.updateClose, close),
          button(l10n.updateTryAgain, _start, primary: true, autofocus: true),
        ],
    };
    // Full width so the buttons sit right-aligned, however narrow the body.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 4,
        children: buttons,
      ),
    );
  }
}

/// Scrollable changelog panel. Focusable so a TV remote can scroll it
/// (D-pad Up/Down) — plain scroll views can't be reached with a remote.
class _NotesBox extends StatefulWidget {
  const _NotesBox({required this.title, required this.notes});

  final String title;
  final String notes;

  @override
  State<_NotesBox> createState() => _NotesBoxState();
}

class _NotesBoxState extends State<_NotesBox> {
  final _scroll = ScrollController();
  bool _focused = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_scroll.hasClients) return KeyEventResult.ignored;
    final pos = _scroll.position;
    double? target;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        pos.pixels < pos.maxScrollExtent) {
      target = pos.pixels + 120;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        pos.pixels > pos.minScrollExtent) {
      target = pos.pixels - 120;
    }
    // At either end, let the D-pad move focus on (to the buttons) instead.
    if (target == null) return KeyEventResult.ignored;
    _scroll.animateTo(target.clamp(pos.minScrollExtent, pos.maxScrollExtent),
        duration: motionDuration(const Duration(milliseconds: 120)), curve: Curves.easeOut);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Focus(
      onKeyEvent: _onKey,
      onFocusChange: (f) => setState(() => _focused = f),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused && PlatformHelper.isTV(context)
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title,
                  style: theme.textTheme.titleSmall!
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (widget.notes.isEmpty)
                Text(AppLocalizations.of(context).updateNoNotes,
                    style: theme.textTheme.bodyMedium)
              else
                ReleaseNotes(widget.notes),
            ],
          ),
        ),
      ),
    );
  }
}
