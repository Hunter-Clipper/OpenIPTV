import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/update_service.dart';
import 'package:open_iptv/shared/widgets/settings_group.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';

/// Whether the "OpenIPTV Video" car add-on is installed and current.
enum CarVideoAddonStatus { missing, outdated, installed }

CarVideoAddonStatus carVideoAddonStatus(int? installedVersion) {
  if (installedVersion == null) return CarVideoAddonStatus.missing;
  return installedVersion < carVideoAddonVersion
      ? CarVideoAddonStatus.outdated
      : CarVideoAddonStatus.installed;
}

/// Settings → Playback → Video in the Car (phones). Android Auto shows one
/// entry per app and OpenIPTV's is the audio one, so the car-screen video
/// lives in a small add-on app; this row installs or updates it.
class CarVideoAddonTile extends ConsumerStatefulWidget {
  const CarVideoAddonTile({super.key});

  @override
  ConsumerState<CarVideoAddonTile> createState() => _CarVideoAddonTileState();
}

class _CarVideoAddonTileState extends ConsumerState<CarVideoAddonTile>
    with WidgetsBindingObserver {
  CarVideoAddonStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the system installer: show the new state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final v = await ref
        .read(updateServiceProvider)
        .packageVersion(carVideoAddonPackage);
    if (mounted) setState(() => _status = carVideoAddonStatus(v));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = switch (_status) {
      null => '',
      CarVideoAddonStatus.missing => 'Watch on the car screen while parked',
      CarVideoAddonStatus.outdated => 'Update available for the add-on',
      CarVideoAddonStatus.installed => 'Add-on installed',
    };
    return TvActivatable(
      onTap: _open,
      builder: (onTap) => ListTile(
        leading: const IconBadge(icon: Icons.directions_car_outlined),
        title: const Text('Video in the Car'),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Future<void> _open() async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CarVideoAddonDialog(
          status: _status ?? CarVideoAddonStatus.missing),
    );
    await _refresh();
  }
}

enum _Phase { info, needsPermission, downloading, handedOff, unavailable, failed }

class _CarVideoAddonDialog extends ConsumerStatefulWidget {
  const _CarVideoAddonDialog({required this.status});

  final CarVideoAddonStatus status;

  @override
  ConsumerState<_CarVideoAddonDialog> createState() =>
      _CarVideoAddonDialogState();
}

class _CarVideoAddonDialogState extends ConsumerState<_CarVideoAddonDialog>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.info;
  double? _progress;
  File? _apk;

  UpdateService get _service => ref.read(updateServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_phase == _Phase.needsPermission) {
      _start();
    } else if (_phase == _Phase.handedOff) {
      // Installed? Then there's nothing left to do here.
      _service.packageVersion(carVideoAddonPackage).then((v) {
        if (mounted &&
            carVideoAddonStatus(v) == CarVideoAddonStatus.installed) {
          Navigator.of(context).pop();
        }
      });
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
      final info = await _service.fetchLatest(assetName: carVideoAddonAsset);
      if (info == null) {
        if (mounted) setState(() => _phase = _Phase.unavailable);
        return;
      }
      final apk = await _service.download(info, fileName: 'OpenIPTV-car-video',
          onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      _apk = apk;
      await _install(apk);
    } catch (e) {
      debugPrint('[OTV-update] car add-on download/install failed: $e');
      if (mounted) setState(() => _phase = _Phase.failed);
    }
  }

  Future<void> _install(File apk) async {
    await _service.install(apk);
    if (mounted) setState(() => _phase = _Phase.handedOff);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.directions_car_outlined),
      title: const Text('Video in the Car'),
      scrollable: true,
      content: _body(Theme.of(context)),
      actions: _actions(),
    );
  }

  Widget _body(ThemeData theme) {
    final style = theme.textTheme.bodyMedium;
    switch (_phase) {
      case _Phase.info:
        final installed = widget.status == CarVideoAddonStatus.installed;
        return Text(
          'Watch on your car\'s screen with Android Auto while parked. '
          'Android Auto closes the picture when you start driving; the '
          'sound keeps playing.\n\n'
          'How to watch: pick a channel, movie or episode in OpenIPTV on '
          'the car screen, then open OpenIPTV Video.\n\n'
          '${installed ? 'The add-on is installed.' : widget.status == CarVideoAddonStatus.outdated ? 'A newer version of the add-on is available.' : 'This needs a small add-on app, OpenIPTV Video (about 1 MB).'}'
          '\n\nIf it doesn\'t show up in the car: in the Android Auto app on '
          'your phone, turn on developer settings and "Unknown sources".',
          style: style,
        );
      case _Phase.needsPermission:
        return Text(
          'To install the add-on, OpenIPTV needs permission to install apps.'
          '\n\nTap Open Settings, turn on "Allow from this source", then '
          'come back here — the install will continue automatically.',
          style: style,
        );
      case _Phase.downloading:
        final pct = _progress == null ? null : (_progress! * 100).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pct == null ? 'Downloading…' : 'Downloading… $pct%',
                style: style),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: _progress, minHeight: 6),
            ),
          ],
        );
      case _Phase.handedOff:
        return Text(
          'Follow the prompts on screen to finish installing.\n\n'
          'If nothing appeared, or you cancelled, tap Install again.',
          style: style,
        );
      case _Phase.unavailable:
        return Text(
          "The add-on isn't available to download yet. It comes with the "
          'next OpenIPTV release.',
          style: style,
        );
      case _Phase.failed:
        return Text(
          "The add-on couldn't be downloaded. Check your internet "
          'connection and try again.',
          style: style,
        );
    }
  }

  List<Widget> _actions() {
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
    return switch (_phase) {
      _Phase.info => [
          if (widget.status == CarVideoAddonStatus.installed)
            button('Done', close, primary: true, autofocus: true)
          else ...[
            button('Not now', close),
            button(
                widget.status == CarVideoAddonStatus.outdated
                    ? 'Update'
                    : 'Install',
                _start,
                primary: true,
                autofocus: true),
          ],
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
      _Phase.unavailable => [button('Close', close, primary: true)],
      _Phase.failed => [
          button('Close', close),
          button('Try again', _start, primary: true, autofocus: true),
        ],
    };
  }
}
