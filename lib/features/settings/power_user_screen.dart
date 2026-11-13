import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/shared/utils/motion.dart';
import 'package:open_iptv/core/services/buffer_preset.dart';
import 'package:open_iptv/core/services/native_video_player.dart';
import 'package:open_iptv/core/services/graphics_mode.dart';
import 'package:open_iptv/core/services/video_layer_mode.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/network_info.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/speed_test.dart';
import 'package:open_iptv/core/services/vpn_service.dart';
import 'package:open_iptv/core/services/user_agent.dart';
import 'package:open_iptv/core/storage/preferences.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/utils/snack_bar_utils.dart';
import 'package:open_iptv/shared/widgets/device_file_picker.dart';
import 'package:open_iptv/shared/widgets/settings_group.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

/// Settings → Advanced → Power User Tools (#41). Phase 1: what the device's
/// connection looks like right now, for diagnosing provider problems.
class PowerUserScreen extends ConsumerStatefulWidget {
  const PowerUserScreen({super.key});

  @override
  ConsumerState<PowerUserScreen> createState() => _PowerUserScreenState();
}

class _PowerUserScreenState extends ConsumerState<PowerUserScreen> {
  NetworkInfo? _network;
  String? _publicIp;
  bool _checkingPublicIp = false;
  bool _publicIpFailed = false;

  final _vpn = VpnService();
  VpnProfile? _vpnProfile;
  VpnStatus _vpnStatus = const VpnStatus();
  bool _vpnBusy = false;
  Timer? _vpnTimer;

  OpenVpnProfile? _ovpn;
  OpenVpnStatus _ovpnStatus = const OpenVpnStatus();

  GraphicsModeInfo? _graphics;
  VideoLayerInfo? _layer;

  final _scroll = ScrollController();

  /// TV: the page scrolls only as the remote's focus moves. Keep the
  /// focused row a little below the top, so the section title and
  /// description above it stay in view (they're never focused themselves),
  /// and reach the very top/bottom at the first/last row.
  void _followFocus() {
    if (!mounted || !PlatformHelper.isTV(context)) return;
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null || !ctx.mounted) return;
    if (Scrollable.maybeOf(ctx)?.position != _scroll.positions.firstOrNull) {
      return; // not on this page (a dialog, the app bar)
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ctx.mounted) return;
      Scrollable.ensureVisible(ctx,
          alignment: 0.35,
          duration: motionDuration(const Duration(milliseconds: 150)),
          curve: Curves.easeOut);
    });
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_followFocus);
    _refresh();
    _loadVpn();
    _loadGraphics();
    _loadLayer();
    // Live tunnel status (traffic, last handshake) while this screen is up.
    _vpnTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollVpn());
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_followFocus);
    _scroll.dispose();
    _vpnTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVpn() async {
    final p = await _vpn.loadProfile();
    final o = await _vpn.loadOpenVpn();
    if (!mounted) return;
    setState(() {
      _vpnProfile = p;
      _ovpn = o;
    });
    await _pollVpn();
  }

  Future<void> _pollVpn() async {
    if (_vpnProfile == null && _ovpn == null) return;
    final st = _vpnProfile == null ? const VpnStatus() : await _vpn.status();
    final os =
        _ovpn == null ? const OpenVpnStatus() : await _vpn.openVpnStatus();
    if (!mounted) return;
    final changed = st.up != _vpnStatus.up || os.up != _ovpnStatus.up;
    final failed = os.state == 'error' && _ovpnStatus.state != 'error';
    setState(() {
      _vpnStatus = st;
      _ovpnStatus = os;
    });
    if (failed) _say(_openVpnError(AppLocalizations.of(context), os.error));
    // The connection details (VPN on/off, addresses) change with it.
    if (changed) unawaited(_refresh());
  }

  static String _openVpnError(AppLocalizations l10n, String? e) {
    final t = (e ?? '').toLowerCase();
    if (t.contains('auth')) return l10n.powerUserOvpnAuthFailed;
    if (t.contains('timeout') ||
        t.contains('resolve') ||
        t.contains('network')) {
      return l10n.powerUserOvpnUnreachable;
    }
    return l10n.powerUserOvpnConnectFailed;
  }

  Future<void> _importOpenVpn() async {
    final l10n = AppLocalizations.of(context);
    final file = await pickDeviceFile(context,
        title: l10n.powerUserPickOvpn, extensions: const ['ovpn', 'conf']);
    if (file == null || !mounted) return;
    final text = utf8.decode(file.bytes, allowMalformed: true);
    final problem = await _vpn.validateOpenVpn(text, l10n);
    if (!mounted) return;
    String? user;
    String? pass;
    if (problem == 'needs_login') {
      final login = await _askLogin();
      if (login == null || !mounted) return;
      (user, pass) = login;
    } else if (problem != null) {
      _say(problem);
      return;
    }
    final name = file.name.replaceAll(RegExp(r'\.(ovpn|conf)$'), '');
    final profile =
        OpenVpnProfile(name: name, config: text, user: user, pass: pass);
    await _vpn.saveOpenVpn(profile);
    if (!mounted) return;
    setState(() => _ovpn = profile);
    _say(l10n.powerUserProfileAdded(name));
  }

  /// Username and password for a profile that asks for them.
  Future<(String, String)?> _askLogin() async {
    final l10n = AppLocalizations.of(context);
    final user = TextEditingController();
    final pass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.powerUserVpnLoginTitle),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.powerUserVpnLoginBody),
            const SizedBox(height: 12),
            TvTextFieldGate(
              autofocus: true,
              builder: (context, node) => TextField(
                focusNode: node,
                controller: user,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.powerUserUsername),
              ),
            ),
            const SizedBox(height: 8),
            TvTextFieldGate(
              builder: (context, node) => TextField(
                focusNode: node,
                controller: pass,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(labelText: l10n.powerUserPassword),
                onSubmitted: (_) => Navigator.of(ctx).pop(true),
              ),
            ),
          ],
        ),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(false),
            builder: (onTap) => TextButton(
                onPressed: onTap, child: Text(l10n.commonCancel)),
          ),
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(true),
            builder: (onTap) => FilledButton(
                onPressed: onTap, child: Text(l10n.powerUserSave)),
          ),
        ],
      ),
    );
    final result = ok == true && user.text.trim().isNotEmpty
        ? (user.text.trim(), pass.text)
        : null;
    user.dispose();
    pass.dispose();
    return result;
  }

  Future<void> _toggleOpenVpn() async {
    final profile = _ovpn;
    if (profile == null || _vpnBusy) return;
    setState(() => _vpnBusy = true);
    if (_ovpnStatus.state != 'off' && _ovpnStatus.state != 'error') {
      await _vpn.disconnectOpenVpn();
    } else {
      final prefs = ref.read(appPreferencesProvider).valueOrNull;
      // One VPN at a time.
      if (_vpnStatus.up) await _vpn.disconnect();
      await prefs?.setVpnKind('openvpn');
      final r =
          await _vpn.connectOpenVpn(profile, route: prefs?.vpnRoute ?? 'app');
      if (mounted) {
        _say(vpnConnectMessage(
            AppLocalizations.of(context), r == 'ok' ? 'starting' : r));
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _pollVpn();
    if (mounted) setState(() => _vpnBusy = false);
  }

  Future<void> _changeOpenVpnLogin() async {
    final profile = _ovpn;
    if (profile == null) return;
    final l10n = AppLocalizations.of(context);
    final login = await _askLogin();
    if (login == null || !mounted) return;
    final updated = OpenVpnProfile(
        name: profile.name,
        config: profile.config,
        user: login.$1,
        pass: login.$2);
    await _vpn.saveOpenVpn(updated);
    if (!mounted) return;
    setState(() => _ovpn = updated);
    _say(l10n.powerUserVpnLoginSaved);
  }

  Future<void> _removeOpenVpn() async {
    if (await _confirmRemove() != true) return;
    await _vpn.deleteOpenVpn();
    final prefs = ref.read(appPreferencesProvider).valueOrNull;
    if (_vpnProfile == null) await prefs?.setVpnAutoConnect(false);
    if (prefs?.vpnKind == 'openvpn') await prefs?.setVpnKind('wireguard');
    if (!mounted) return;
    setState(() {
      _ovpn = null;
      _ovpnStatus = const OpenVpnStatus();
    });
    unawaited(_refresh());
  }

  Future<void> _importVpn() async {
    final l10n = AppLocalizations.of(context);
    final file = await pickDeviceFile(context,
        title: l10n.powerUserPickWireGuard, extensions: const ['conf']);
    if (file == null || !mounted) return;
    final text = utf8.decode(file.bytes, allowMalformed: true);
    final problem = await _vpn.validate(text, l10n);
    if (!mounted) return;
    if (problem != null) {
      _say(problem);
      return;
    }
    final name = file.name.replaceAll(RegExp(r'\.conf$'), '');
    final profile = VpnProfile(name: name, config: text);
    await _vpn.saveProfile(profile);
    if (!mounted) return;
    setState(() => _vpnProfile = profile);
    _say(l10n.powerUserProfileAdded(name));
  }

  Future<void> _toggleVpn() async {
    final profile = _vpnProfile;
    if (profile == null || _vpnBusy) return;
    setState(() => _vpnBusy = true);
    if (_vpnStatus.up) {
      await _vpn.disconnect();
    } else {
      final prefs = ref.read(appPreferencesProvider).valueOrNull;
      // One VPN at a time.
      if (_ovpnStatus.state != 'off') await _vpn.disconnectOpenVpn();
      await prefs?.setVpnKind('wireguard');
      final r = await _vpn.connect(profile, route: prefs?.vpnRoute ?? 'app');
      if (mounted) _say(vpnConnectMessage(AppLocalizations.of(context), r));
    }
    await _pollVpn();
    if (mounted) setState(() => _vpnBusy = false);
  }

  Future<bool?> _confirmRemove() {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.powerUserRemoveTitle),
        content: Text(l10n.powerUserRemoveBody),
        actions: [
          TvActivatable(
            autofocus: true,
            onTap: () => Navigator.of(ctx).pop(false),
            builder: (onTap) => TextButton(
                onPressed: onTap, child: Text(l10n.commonCancel)),
          ),
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(true),
            builder: (onTap) => FilledButton(
                onPressed: onTap, child: Text(l10n.powerUserRemove)),
          ),
        ],
      ),
    );
  }

  Future<void> _removeVpn() async {
    if (await _confirmRemove() != true) return;
    await _vpn.deleteProfile();
    final prefs = ref.read(appPreferencesProvider).valueOrNull;
    // Nothing left to auto-connect to.
    if (_ovpn == null) await prefs?.setVpnAutoConnect(false);
    if (prefs?.vpnKind == 'wireguard' && _ovpn != null) {
      await prefs?.setVpnKind('openvpn');
    }
    if (!mounted) return;
    setState(() {
      _vpnProfile = null;
      _vpnStatus = const VpnStatus();
    });
    unawaited(_refresh());
  }

  void _say(String message) {
    showSnackBarMessage(context, message);
  }

  Future<void> _refresh() async {
    final info = await readNetworkInfo();
    if (!mounted) return;
    setState(() {
      _network = info;
      // The public address may have changed with the network.
      _publicIp = null;
      _publicIpFailed = false;
    });
  }

  Future<void> _checkPublicIp() async {
    setState(() {
      _checkingPublicIp = true;
      _publicIpFailed = false;
    });
    final ip = await fetchPublicIp();
    if (!mounted) return;
    setState(() {
      _checkingPublicIp = false;
      _publicIp = ip;
      _publicIpFailed = ip == null;
    });
  }

  /// Tap-to-copy on phones; a TV has no clipboard anyone can use, so its
  /// rows aren't focus stops and the remote goes straight to the buttons.
  VoidCallback? _copier(String label, String? value) =>
      value == null || PlatformHelper.isTV(context)
          ? null
          : () => _copy(label, value);

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).powerUserCopied(label))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final net = _network;
    final isTv = PlatformHelper.isTV(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.powerUserTitle),
        actions: [
          TvActivatable(
        round: true,
            onTap: _refresh,
            builder: (onTap) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.powerUserRefreshTooltip,
              onPressed: onTap,
            ),
          ),
        ],
      ),
      // A plain scroll view, not a lazy ListView: on TV the remote can only
      // move to rows that exist, and a lazy list hadn't built the ones
      // below the screen yet. The page is short, so building it all is cheap.
      body: SingleChildScrollView(
        controller: _scroll,
        // Room for the system navigation bar (a ListView adds this itself;
        // a SingleChildScrollView with its own padding doesn't).
        padding: EdgeInsets.only(
            bottom: 32 + MediaQuery.paddingOf(context).bottom),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsGroup(
            title: l10n.powerUserNetworkTitle,
            description: isTv
                ? l10n.powerUserNetworkDescription
                : l10n.powerUserNetworkDescriptionCopy,
            children: net == null
                ? [
                    ListTile(
                      leading: const IconBadge(icon: Icons.wifi_find_outlined),
                      title: Text(l10n.powerUserCheckingConnection),
                    ),
                  ]
                : [
                    _InfoRow(
                      icon: switch (net.transport) {
                        'wifi' => Icons.wifi,
                        'ethernet' => Icons.settings_ethernet,
                        'cellular' => Icons.signal_cellular_alt,
                        'none' => Icons.wifi_off,
                        _ => Icons.lan_outlined,
                      },
                      label: l10n.powerUserConnection,
                      value: net.connectionLabel,
                      autofocus: true,
                    ),
                    _InfoRow(
                      icon: net.vpn ? Icons.vpn_lock : Icons.vpn_lock_outlined,
                      label: 'VPN',
                      value: net.vpn ? l10n.powerUserOn : l10n.powerUserOff,
                    ),
                    if (net.connected)
                      _InfoRow(
                        icon: Icons.router_outlined,
                        label: l10n.powerUserDeviceIp,
                        value: net.orderedAddresses.isEmpty
                            ? l10n.powerUserNotAvailable
                            : net.orderedAddresses.join('\n'),
                        onTap: _copier(l10n.powerUserDeviceIp,
                            net.orderedAddresses.firstOrNull),
                      ),
                    if (net.vpn && net.vpnAddresses.isNotEmpty)
                      _InfoRow(
                        icon: Icons.vpn_lock_outlined,
                        label: l10n.powerUserVpnAddress,
                        value: net.vpnAddresses.join('\n'),
                        onTap: _copier(l10n.powerUserVpnAddress,
                            net.vpnAddresses.firstOrNull),
                      ),
                    if (net.connected) _publicIpRow(theme),
                    if (net.connected && net.dns.isNotEmpty)
                      _InfoRow(
                        icon: Icons.dns_outlined,
                        label: l10n.powerUserDnsServers,
                        value: net.dns.join('\n'),
                      ),
                  ],
          ),
          // Network: VPN, speed, how the player introduces itself.
          _vpnGroup(),
          _speedGroup(),
          _userAgentGroup(),
          // Picture and sound.
          _graphicsGroup(),
          if (isTv) _layerGroup(),
          _frameRateGroup(),
          if (isTv) ...[_passthroughGroup(), _tunnelingGroup()],
          // Memory and storage.
          _bufferGroup(),
          _imageQualityGroup(),
          _databaseGroup(),
        ],
      ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VPN
  // ---------------------------------------------------------------------------

  Widget _vpnGroup() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profile = _vpnProfile;
    final st = _vpnStatus;
    final ovpn = _ovpn;
    final os = _ovpnStatus;
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final route = prefs?.vpnRoute ?? 'app';

    String wgText() {
      if (profile == null) return l10n.powerUserWgImportHint;
      final where = profile.endpoint == null ? '' : ' · ${profile.endpoint}';
      if (!st.up) return l10n.powerUserVpnStateOff(profile.name, where);
      final hs = st.lastHandshake;
      final ago = hs == null
          ? l10n.powerUserHandshakeWaiting
          : l10n.powerUserHandshakeAnswered(_ago(l10n, hs));
      return l10n.powerUserWgConnected(profile.name, where,
          formatBytes(st.rxBytes), formatBytes(st.txBytes), ago);
    }

    String ovpnText() {
      if (ovpn == null) return l10n.powerUserOvpnImportHint;
      final where = ovpn.endpoint == null ? '' : ' · ${ovpn.endpoint}';
      return switch (os.state) {
        'connected' => l10n.powerUserOvpnConnected(ovpn.name, where,
            formatBytes(os.rxBytes), formatBytes(os.txBytes)),
        'connecting' => l10n.powerUserOvpnConnecting(ovpn.name, where),
        'error' => l10n.powerUserOvpnError(ovpn.name, where),
        _ => l10n.powerUserVpnStateOff(ovpn.name, where),
      };
    }

    Widget actionButton(String label, VoidCallback onRun) => TvActivatable(
          // A no-op while busy, so TV focus stays put.
          onTap: _vpnBusy ? () {} : onRun,
          builder: (onTap) =>
              TextButton(onPressed: onTap, child: Text(label)),
        );

    final ovpnOn = os.state == 'connected' || os.state == 'connecting';

    return SettingsGroup(
      title: 'VPN',
      description: l10n.powerUserVpnDescription,
      children: [
        _InfoRow(
          icon: st.up ? Icons.vpn_lock : Icons.vpn_key_outlined,
          label: 'WireGuard',
          value: wgText(),
          trailing: actionButton(
              profile == null
                  ? l10n.powerUserImport
                  : st.up
                      ? l10n.powerUserDisconnect
                      : l10n.powerUserConnect,
              profile == null ? _importVpn : _toggleVpn),
        ),
        _InfoRow(
          icon: os.up ? Icons.vpn_lock : Icons.lock_outline,
          label: 'OpenVPN',
          value: ovpnText(),
          trailing: actionButton(
              ovpn == null
                  ? l10n.powerUserImport
                  : ovpnOn
                      ? l10n.powerUserDisconnect
                      : l10n.powerUserConnect,
              ovpn == null ? _importOpenVpn : _toggleOpenVpn),
        ),
        if (profile != null || ovpn != null) ...[
          for (final (id, label, sub) in [
            ('app', l10n.powerUserRouteApp, l10n.powerUserRouteAppHint),
            ('device', l10n.powerUserRouteDevice,
                l10n.powerUserRouteDeviceHint),
          ])
            TvActivatable(
              onTap: () async {
                await prefs?.setVpnRoute(id);
                if (!mounted) return;
                setState(() {});
                if (_vpnStatus.up || _ovpnStatus.up) {
                  _say(l10n.powerUserReconnectToApply);
                }
              },
              builder: (tap) => ListTile(
                leading: Icon(
                  route == id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: route == id ? theme.colorScheme.primary : null,
                ),
                title: Text(label),
                subtitle: Text(sub, style: theme.textTheme.bodySmall),
                onTap: tap,
              ),
            ),
          TvActivatable(
            onTap: () async {
              await prefs?.setVpnAutoConnect(!(prefs.vpnAutoConnect));
              if (mounted) setState(() {});
            },
            builder: (tap) => SwitchListTile(
              secondary: const IconBadge(icon: Icons.play_circle_outline),
              title: Text(l10n.powerUserAutoConnect),
              subtitle: Text(l10n.powerUserAutoConnectHint,
                  style: theme.textTheme.bodySmall),
              value: prefs?.vpnAutoConnect ?? false,
              onChanged: tap == null ? null : (_) => tap(),
            ),
          ),
          if (profile != null)
            TvActivatable(
              onTap: _removeVpn,
              builder: (tap) => ListTile(
                leading: const IconBadge(icon: Icons.delete_outline),
                title: Text(l10n.powerUserRemoveWireGuard),
                onTap: tap,
              ),
            ),
          if (ovpn != null && ovpn.user != null)
            TvActivatable(
              onTap: _changeOpenVpnLogin,
              builder: (tap) => ListTile(
                leading: const IconBadge(icon: Icons.password),
                title: Text(l10n.powerUserChangeOvpnLogin),
                subtitle: Text(l10n.powerUserSignedInAs(ovpn.user!),
                    style: theme.textTheme.bodySmall),
                onTap: tap,
              ),
            ),
          if (ovpn != null)
            TvActivatable(
              onTap: _removeOpenVpn,
              builder: (tap) => ListTile(
                leading: const IconBadge(icon: Icons.delete_outline),
                title: Text(l10n.powerUserRemoveOpenVpn),
                onTap: tap,
              ),
            ),
        ],
      ],
    );
  }

  static String _ago(AppLocalizations l10n, DateTime t) {
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 5) return l10n.powerUserJustNow;
    if (s < 60) return l10n.powerUserSecondsAgo(s);
    return l10n.powerUserMinutesAgo(s ~/ 60);
  }

  // ---------------------------------------------------------------------------
  // Speed test
  // ---------------------------------------------------------------------------

  _SpeedRun _provider = const _SpeedRun();
  _SpeedRun _internet = const _SpeedRun();

  /// Downloads from the browsed playlist's own server: a movie file if
  /// there is one (full speed), else a live channel (shows whether the
  /// connection keeps up). Tries a few links, since some may be dead.
  Future<void> _testProvider() async {
    final l10n = AppLocalizations.of(context);
    if (_provider.running || _internet.running) return;
    setState(() => _provider = const _SpeedRun(running: true));
    final db = ref.read(appDatabaseProvider);
    final candidates =
        await db.speedTestCandidates(ref.read(activeSourceIdProvider));
    SpeedResult? result;
    for (final c in candidates) {
      final uri = Uri.tryParse(c.url);
      if (uri == null || !uri.hasScheme) continue;
      try {
        result = await measureDownload(uri,
            paced: !c.movie,
            onProgress: (m) => _live(m, provider: true));
        break;
      } catch (_) {
        continue; // dead link: try the next one
      }
    }
    if (!mounted) return;
    setState(() => _provider = result == null
        ? _SpeedRun(
            error: candidates.isEmpty
                ? l10n.powerUserSpeedNothingToTest
                : l10n.powerUserSpeedProviderFailed)
        : _SpeedRun(result: result));
  }

  Future<void> _testInternet() async {
    final l10n = AppLocalizations.of(context);
    if (_provider.running || _internet.running) return;
    setState(() => _internet = const _SpeedRun(running: true));
    SpeedResult? result;
    try {
      result = await measureDownload(internetSpeedUrl(),
          onProgress: (m) => _live(m, provider: false));
    } catch (_) {}
    if (!mounted) return;
    setState(() => _internet = result == null
        ? _SpeedRun(error: l10n.powerUserSpeedInternetFailed)
        : _SpeedRun(result: result));
  }

  DateTime _lastProgress = DateTime(0);
  void _live(double mbps, {required bool provider}) {
    final now = DateTime.now();
    if (!mounted || now.difference(_lastProgress).inMilliseconds < 250) return;
    _lastProgress = now;
    setState(() {
      final run = _SpeedRun(running: true, liveMbps: mbps);
      provider ? _provider = run : _internet = run;
    });
  }

  Widget _speedGroup() {
    final l10n = AppLocalizations.of(context);
    return SettingsGroup(
      title: l10n.powerUserSpeedTitle,
      description: l10n.powerUserSpeedDescription,
      children: [
        _speedRow(
          icon: Icons.speed,
          label: l10n.powerUserSpeedProviderLabel,
          idle: l10n.powerUserSpeedProviderIdle,
          run: _provider,
          onRun: _testProvider,
        ),
        _speedRow(
          icon: Icons.language,
          label: l10n.powerUserSpeedInternetLabel,
          idle: l10n.powerUserSpeedInternetIdle(kInternetSpeedHost),
          run: _internet,
          onRun: _testInternet,
        ),
      ],
    );
  }

  Widget _speedRow({
    required IconData icon,
    required String label,
    required String idle,
    required _SpeedRun run,
    required VoidCallback onRun,
  }) {
    final l10n = AppLocalizations.of(context);
    final r = run.result;
    final String value;
    if (run.running) {
      value = run.liveMbps == null
          ? l10n.powerUserSpeedConnecting
          : l10n.powerUserSpeedTesting(run.liveMbps!.toStringAsFixed(1));
    } else if (r != null) {
      final result = l10n.powerUserSpeedResult(r.mbps.toStringAsFixed(1),
          r.verdict(l10n), r.firstByte.inMilliseconds);
      value = r.paced
          ? '$result\n${l10n.powerUserSpeedPacedNote}'
          : result;
    } else {
      value = run.error ?? idle;
    }
    return _InfoRow(
      icon: icon,
      label: label,
      value: value,
      // Stays enabled while running (a no-op) so TV focus doesn't jump.
      trailing: TvActivatable(
        onTap: run.running ? () {} : onRun,
        builder: (onTap) => TextButton(
          onPressed: onTap,
          child: Text(r == null && run.error == null
              ? l10n.powerUserRun
              : l10n.powerUserRunAgain),
        ),
      ),
    );
  }

  // Moved here from the main Settings list so a stray OK can't flip it.
  Widget _databaseGroup() {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final skip = prefs?.skipDbEncryption ?? false;

    Future<void> change(bool enable) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(enable
              ? l10n.powerUserDbSkipQuestion
              : l10n.powerUserDbTurnOnQuestion),
          content: Text(enable
              ? l10n.powerUserDbSkipBody
              : l10n.powerUserDbTurnOnBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(enable
                  ? l10n.powerUserDbEnable
                  : l10n.powerUserDbTurnOn),
            ),
          ],
        ),
      );
      if (confirmed != true || prefs == null || !mounted) return;
      await prefs.setSkipDbEncryption(enable);
      ref.invalidate(appPreferencesProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.powerUserDbReopenTitle),
          content: Text(l10n.powerUserDbReopenBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.powerUserDbClose),
            ),
          ],
        ),
      );
      exit(0);
    }

    return SettingsGroup(
      title: l10n.powerUserDbTitle,
      description: l10n.powerUserDbDescription,
      children: [
        TvActivatable(
          onTap: () => change(!skip),
          builder: (tap) => SwitchListTile(
            secondary: const IconBadge(icon: Icons.lock_open),
            title: Text(l10n.powerUserDbSkipTitle),
            value: skip,
            onChanged: tap == null ? null : (_) => tap(),
          ),
        ),
      ],
    );
  }

  Widget _bufferGroup() {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final current = BufferPreset.fromId(prefs?.bufferPreset);
    return SettingsGroup(
      title: l10n.powerUserBufferTitle,
      description: l10n.powerUserBufferDescription,
      children: [
        for (final preset in BufferPreset.values)
          TvActivatable(
            onTap: () async {
              await prefs?.setBufferPreset(preset.id);
              if (mounted) setState(() {});
            },
            builder: (tap) => ListTile(
              leading: Icon(
                preset == current
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: preset == current
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(preset.label(l10n)),
              subtitle: Text(preset.description(l10n),
                  style: Theme.of(context).textTheme.bodySmall),
              onTap: tap,
            ),
          ),
      ],
    );
  }

  Widget _imageQualityGroup() {
    final l10n = AppLocalizations.of(context);
    final on = ref.watch(fullResImagesProvider);
    Future<void> change(bool v) async {
      final prefs = await ref.read(appPreferencesProvider.future);
      await setFullResImages(ref, v, prefs);
    }

    return SettingsGroup(
      title: l10n.powerUserPicturesTitle,
      description: l10n.powerUserPicturesDescription,
      children: [
        TvActivatable(
          onTap: () => change(!on),
          builder: (tap) => SwitchListTile(
            secondary: const IconBadge(icon: Icons.high_quality_outlined),
            title: Text(l10n.powerUserFullResTitle),
            value: on,
            onChanged: tap == null ? null : (_) => tap(),
          ),
        ),
      ],
    );
  }

  Widget _frameRateGroup() {
    final l10n = AppLocalizations.of(context);
    final on = ref.watch(autoFrameRateProvider);
    Future<void> change(bool v) async {
      final prefs = await ref.read(appPreferencesProvider.future);
      await setAutoFrameRate(ref, v, prefs);
    }

    return SettingsGroup(
      title: l10n.powerUserFrameRateTitle,
      description: l10n.powerUserFrameRateDescription,
      children: [
        TvActivatable(
          onTap: () => change(!on),
          builder: (tap) => SwitchListTile(
            secondary: const IconBadge(icon: Icons.speed_rounded),
            title: Text(l10n.powerUserFrameRateSwitch),
            value: on,
            onChanged: tap == null ? null : (_) => tap(),
          ),
        ),
      ],
    );
  }

  // Audio passthrough and tunneled playback (#159): 'auto' | 'on' | 'off'.
  Widget _outputGroup({
    required String title,
    required String description,
    required String current,
    required Future<void> Function(String) save,
    required String autoText,
    required String onText,
    required String offText,
  }) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    Widget row(String id, String label, String text) => TvActivatable(
          onTap: () async {
            await save(id);
            final prefs = ref.read(appPreferencesProvider).valueOrNull;
            if (prefs != null) {
              await NativeVideoPlayer.setOutputModes(
                  passthrough: prefs.audioPassthrough,
                  tunneling: prefs.tunneledPlayback);
            }
            if (mounted) setState(() {});
          },
          builder: (tap) => ListTile(
            leading: Icon(
              id == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: id == current ? theme.colorScheme.primary : null,
            ),
            title: Text(label),
            subtitle: Text(text, style: theme.textTheme.bodySmall),
            onTap: tap,
          ),
        );
    return SettingsGroup(
      title: title,
      description: description,
      children: [
        row('auto', l10n.powerUserAutomatic, autoText),
        row('on', l10n.powerUserOn, onText),
        row('off', l10n.powerUserOff, offText),
      ],
    );
  }

  Widget _passthroughGroup() {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    return _outputGroup(
      title: l10n.powerUserPassthroughTitle,
      description: l10n.powerUserPassthroughDescription,
      current: prefs?.audioPassthrough ?? 'auto',
      save: (v) async => prefs?.setAudioPassthrough(v),
      autoText: l10n.powerUserPassthroughAuto,
      onText: l10n.powerUserPassthroughOn,
      offText: l10n.powerUserPassthroughOff,
    );
  }

  Widget _tunnelingGroup() {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    return _outputGroup(
      title: l10n.powerUserTunnelingTitle,
      description: l10n.powerUserTunnelingDescription,
      current: prefs?.tunneledPlayback ?? 'auto',
      save: (v) async => prefs?.setTunneledPlayback(v),
      autoText: l10n.powerUserTunnelingAuto,
      onText: l10n.powerUserTunnelingOn,
      offText: l10n.powerUserTunnelingOff,
    );
  }

  Future<void> _loadLayer() async {
    final info = await videoLayerInfo();
    if (!mounted) return;
    setState(() => _layer = info);
  }

  Widget _layerGroup() {
    final info = _layer;
    if (info == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SettingsGroup(
      title: l10n.powerUserLayerTitle,
      description: '${l10n.powerUserLayerDescription}\n'
          '${l10n.powerUserInUseNow(info.active ? l10n.powerUserYes : l10n.powerUserNo)}',
      children: [
        for (final mode in VideoLayerSetting.values)
          TvActivatable(
            onTap: () => _pickLayer(mode),
            builder: (tap) => ListTile(
              leading: Icon(
                mode == info.setting
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: mode == info.setting ? theme.colorScheme.primary : null,
              ),
              title: Text(mode.label(l10n)),
              subtitle: Text(mode.description(l10n),
                  style: theme.textTheme.bodySmall),
              onTap: tap,
            ),
          ),
      ],
    );
  }

  Future<void> _pickLayer(VideoLayerSetting mode) async {
    final l10n = AppLocalizations.of(context);
    final before = _layer;
    if (before == null || mode == before.setting) return;
    final after = await setVideoLayerMode(mode);
    if (!mounted) return;
    if (after == null) {
      _say(l10n.powerUserLayerChangeFailed);
      return;
    }
    setState(() => _layer = after);
    if (!after.needsRestart) return;
    final restart = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.powerUserRestartTitle),
        content: Text(l10n.powerUserRestartLayerBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.powerUserLater),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.powerUserRestartNow),
          ),
        ],
      ),
    );
    if (restart == true && !await restartApp() && mounted) {
      _say(l10n.powerUserRestartFailed);
    }
  }

  Future<void> _loadGraphics() async {
    final info = await graphicsModeInfo();
    if (!mounted) return;
    setState(() => _graphics = info);
  }

  Widget _graphicsGroup() {
    final info = _graphics;
    // TVs only (the native side is also missing in tests and on web).
    if (!showGraphicsMode(isTv: PlatformHelper.isTV(context), info: info)) {
      return const SizedBox.shrink();
    }
    // Non-null from here: showGraphicsMode checked it.
    final current = info!;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final activeMode = current.active == 'compat'
        ? GraphicsModeSetting.compatibility
        : GraphicsModeSetting.standard;
    return SettingsGroup(
      title: l10n.powerUserGraphicsTitle,
      description: '${l10n.powerUserGraphicsDescription}'
          '${current.chip == null ? '' : '\n${l10n.powerUserGraphicsThisDevice(current.chip!)}'}'
          '\n${l10n.powerUserInUseNow(activeMode.label(l10n))}',
      children: [
        for (final mode in GraphicsModeSetting.values)
          TvActivatable(
            onTap: () => _pickGraphics(mode),
            builder: (tap) => ListTile(
              leading: Icon(
                mode == current.setting
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: mode == current.setting ? theme.colorScheme.primary : null,
              ),
              title: Text(mode.label(l10n)),
              subtitle: Text(mode.description(l10n),
                  style: theme.textTheme.bodySmall),
              onTap: tap,
            ),
          ),
      ],
    );
  }

  Future<void> _pickGraphics(GraphicsModeSetting mode) async {
    final l10n = AppLocalizations.of(context);
    final before = _graphics;
    if (before == null || mode == before.setting) return;
    final after = await setGraphicsMode(mode);
    if (!mounted) return;
    if (after == null) {
      _say(l10n.powerUserGraphicsChangeFailed);
      return;
    }
    setState(() => _graphics = after);
    if (!after.needsRestart) return;
    final restart = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.powerUserRestartTitle),
        content: Text(l10n.powerUserRestartGraphicsBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.powerUserLater),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.powerUserRestartNow),
          ),
        ],
      ),
    );
    if (restart == true && !await restartApp() && mounted) {
      _say(l10n.powerUserRestartFailed);
    }
  }

  Widget _userAgentGroup() {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final custom = prefs?.userAgent;
    return SettingsGroup(
      title: l10n.powerUserUaTitle,
      description: l10n.powerUserUaDescription,
      children: [
        TvActivatable(
          onTap: _editUserAgent,
          builder: (tap) => ListTile(
            leading: const IconBadge(icon: Icons.badge_outlined),
            title: Text(l10n.powerUserUaRow),
            subtitle: Text(
              custom ?? l10n.powerUserUaDefault,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: tap,
          ),
        ),
      ],
    );
  }

  Future<void> _editUserAgent() async {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.read(appPreferencesProvider).valueOrNull;
    if (prefs == null) return;
    final controller = TextEditingController(text: prefs.userAgent ?? '');
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          void trySave() {
            try {
              parseCustomUserAgent(controller.text);
              Navigator.of(ctx).pop(true);
            } on FormatException catch (e) {
              setLocal(() => error = e.message);
            }
          }

          return AlertDialog(
            title: Text(l10n.powerUserUaTitle),
            scrollable: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.powerUserUaEmptyNote),
                const SizedBox(height: 12),
                TvTextFieldGate(
                  autofocus: true,
                  builder: (context, node) => TextField(
                    focusNode: node,
                    controller: controller,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.powerUserUaTitle,
                      hintText: l10n.powerUserUaHint,
                      errorText: error,
                    ),
                    onSubmitted: (_) => trySave(),
                  ),
                ),
              ],
            ),
            actions: [
              TvActivatable(
                onTap: () {
                  controller.clear();
                  Navigator.of(ctx).pop(true);
                },
                builder: (onTap) => TextButton(
                    onPressed: onTap, child: Text(l10n.powerUserUseDefault)),
              ),
              TvActivatable(
                onTap: () => Navigator.of(ctx).pop(false),
                builder: (onTap) => TextButton(
                    onPressed: onTap, child: Text(l10n.commonCancel)),
              ),
              TvActivatable(
                onTap: trySave,
                builder: (onTap) => FilledButton(
                    onPressed: onTap, child: Text(l10n.powerUserSave)),
              ),
            ],
          );
        },
      ),
    );
    final text = controller.text;
    controller.dispose();
    if (saved != true) return;
    await prefs.setUserAgent(parseCustomUserAgent(text));
    if (mounted) setState(() {});
  }

  Widget _publicIpRow(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final ip = _publicIp;
    final String value;
    if (_checkingPublicIp) {
      value = l10n.powerUserChecking;
    } else if (ip != null) {
      value = ip;
    } else if (_publicIpFailed) {
      value = l10n.powerUserCheckFailed;
    } else {
      value = l10n.powerUserPublicIpIdle(kPublicIpService);
    }
    return _InfoRow(
      icon: Icons.public,
      label: l10n.powerUserPublicIp,
      value: value,
      onTap: _copier(l10n.powerUserPublicIp, ip),
      // Stays enabled (a no-op while checking): disabling it removed the
      // remote's focus, which jumped to another row.
      trailing: TvActivatable(
        onTap: _checkingPublicIp ? () {} : _checkPublicIp,
        builder: (onTap) => TextButton(
          onPressed: onTap,
          child: Text(
              ip == null ? l10n.powerUserCheck : l10n.powerUserCheckAgain),
        ),
      ),
    );
  }
}

/// A label / value row; the value is selectable-looking but read-only.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
    this.autofocus = false,
  });

  final bool autofocus;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // On TV every row is a stop for the remote (read-only ones do nothing
    // when pressed), so moving up and down walks the whole page and nothing
    // scrolls out of reach. A row with its own button uses the button.
    final tv = PlatformHelper.isTV(context);
    return TvActivatable(
      autofocus: autofocus && tv,
      onTap: onTap ?? (tv && trailing == null ? () {} : null),
      builder: (tap) => ListTile(
        leading: IconBadge(icon: icon),
        title: Text(label),
        subtitle: Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: trailing,
        onTap: tap,
      ),
    );
  }
}

class _SpeedRun {
  const _SpeedRun({
    this.running = false,
    this.liveMbps,
    this.result,
    this.error,
  });

  final bool running;
  final double? liveMbps;
  final SpeedResult? result;
  final String? error;
}
