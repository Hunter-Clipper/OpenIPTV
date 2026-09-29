import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/update_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/features/updates/release_notes.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

/// Launch-time check: offers an update at most once per
/// [UpdateService.autoCheckInterval], only to admin profiles (installing
/// replaces the app for every profile on the device), never for Play Store
/// installs, and never for a version the user chose to skip.
Future<void> maybePromptForUpdate(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final service = container.read(updateServiceProvider);
  final prefs = await container.read(appPreferencesProvider.future);
  if (!prefs.autoUpdateCheck) return;
  final last = prefs.lastUpdateCheck;
  if (last != null &&
      DateTime.now().difference(last) < UpdateService.autoCheckInterval) {
    return;
  }
  if (!await service.isSelfUpdatable()) return;
  final profile = await container.read(activeProfileProvider.future);
  if (profile?.isAdmin != true) return;

  final update = await service.checkForUpdate();
  await prefs.setLastUpdateCheck(DateTime.now());
  if (update == null) return;
  if (prefs.skippedUpdateVersion == update.version.toString()) return;
  if (!context.mounted) return;
  await showUpdateDialog(context, update);
}

/// Settings → "Check for updates": always checks now and reports the result.
Future<void> checkForUpdateManually(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  final service = container.read(updateServiceProvider);
  final messenger = ScaffoldMessenger.of(context);
  void say(String text) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  if (!await service.isSelfUpdatable()) {
    say('Updates for this install are managed by Google Play.');
    return;
  }
  say('Checking for updates…');
  final (latest, installed) =
      await (service.fetchLatest(), service.installedVersion()).wait;
  final prefs = await container.read(appPreferencesProvider.future);
  await prefs.setLastUpdateCheck(DateTime.now());
  if (latest == null || installed == null) {
    say("Couldn't check for updates. Check your internet connection.");
    return;
  }
  if (!(latest.version > installed)) {
    say("You're up to date (version $installed).");
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
                        Text('Update available',
                            style: theme.textTheme.titleLarge!
                                .copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          from == null
                              ? 'Version ${update.version}'
                              : 'Version $from → ${update.version}',
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
    switch (_phase) {
      case _Phase.offer:
        return _NotesBox(
          title: widget.update.title,
          notes: widget.update.notes,
        );
      case _Phase.needsPermission:
        return Text(
          'To install updates, OpenIPTV needs permission to install apps.\n\n'
          'Tap Open Settings, turn on "Allow from this source", then come '
          'back here — the update will continue automatically.',
          style: theme.textTheme.bodyMedium,
        );
      case _Phase.downloading:
        final pct = _progress == null ? null : (_progress! * 100).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pct == null ? 'Downloading…' : 'Downloading… $pct%',
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
          'Follow the prompts on screen to finish installing. OpenIPTV will '
          'restart on the new version.\n\n'
          "If nothing appeared, or you cancelled, tap Install again.",
          style: theme.textTheme.bodyMedium,
        );
      case _Phase.failed:
        return Text(
          "The update couldn't be downloaded. Check your internet "
          'connection and try again.',
          style: theme.textTheme.bodyMedium,
        );
    }
  }

  Widget _actions() {
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
          if (!widget.manual) button('Skip this version', _skip),
          button('Later', close),
          button('Update now', _start, primary: true, autofocus: true),
        ],
      _Phase.needsPermission => [
          button('Cancel', close),
          button('Open Settings', _service.openInstallPermissionSettings,
              primary: true, autofocus: true),
        ],
      _Phase.downloading => <Widget>[],
      _Phase.handedOff => [
          button('Close', close),
          button('Install again', _start, primary: true, autofocus: true),
        ],
      _Phase.failed => [
          button('Close', close),
          button('Try again', _start, primary: true, autofocus: true),
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
        duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
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
                Text('No release notes provided.',
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
