import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/buffer_preset.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/network_info.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/speed_test.dart';
import 'package:open_iptv/core/services/vpn_service.dart';
import 'package:open_iptv/core/storage/preferences.dart';
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
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut);
    });
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_followFocus);
    _refresh();
    _loadVpn();
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
    if (failed) _say(_openVpnError(os.error));
    // The connection details (VPN on/off, addresses) change with it.
    if (changed) unawaited(_refresh());
  }

  static String _openVpnError(String? e) {
    final t = (e ?? '').toLowerCase();
    if (t.contains('auth')) {
      return 'The VPN server rejected the username or password. Use '
          '"Change OpenVPN login" to fix it.';
    }
    if (t.contains('timeout') ||
        t.contains('resolve') ||
        t.contains('network')) {
      return "Couldn't reach the VPN server. Check the profile and your "
          'connection.';
    }
    return "The VPN couldn't connect. Check the profile and try again.";
  }

  Future<void> _importOpenVpn() async {
    final file = await pickDeviceFile(context,
        title: 'Choose an OpenVPN profile', extensions: const ['ovpn', 'conf']);
    if (file == null || !mounted) return;
    final text = utf8.decode(file.bytes, allowMalformed: true);
    final problem = await _vpn.validateOpenVpn(text);
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
    _say('Profile "$name" added');
  }

  /// Username and password for a profile that asks for them.
  Future<(String, String)?> _askLogin() async {
    final user = TextEditingController();
    final pass = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('VPN login'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This profile needs the username and password from '
                'your VPN provider. They are stored encrypted on this '
                'device.'),
            const SizedBox(height: 12),
            TvTextFieldGate(
              autofocus: true,
              builder: (context, node) => TextField(
                focusNode: node,
                controller: user,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
            ),
            const SizedBox(height: 8),
            TvTextFieldGate(
              builder: (context, node) => TextField(
                focusNode: node,
                controller: pass,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ),
          ],
        ),
        actions: [
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(false),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: const Text('Cancel')),
          ),
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(true),
            builder: (onTap) =>
                FilledButton(onPressed: onTap, child: const Text('Save')),
          ),
        ],
      ),
    );
    final result = ok == true && user.text.isNotEmpty
        ? (user.text, pass.text)
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
      if (mounted) _say(vpnConnectMessage(r == 'ok' ? 'starting' : r));
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _pollVpn();
    if (mounted) setState(() => _vpnBusy = false);
  }

  Future<void> _changeOpenVpnLogin() async {
    final profile = _ovpn;
    if (profile == null) return;
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
    _say('VPN login saved');
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
    final file = await pickDeviceFile(context,
        title: 'Choose a WireGuard profile', extensions: const ['conf']);
    if (file == null || !mounted) return;
    final text = utf8.decode(file.bytes, allowMalformed: true);
    final problem = await _vpn.validate(text);
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
    _say('Profile "$name" added');
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
      if (mounted) _say(vpnConnectMessage(r));
    }
    await _pollVpn();
    if (mounted) setState(() => _vpnBusy = false);
  }

  Future<bool?> _confirmRemove() => showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove VPN profile?'),
        content: const Text('The VPN disconnects and the profile is deleted '
            'from this device. You can import it again later.'),
        actions: [
          TvActivatable(
            autofocus: true,
            onTap: () => Navigator.of(ctx).pop(false),
            builder: (onTap) =>
                TextButton(onPressed: onTap, child: const Text('Cancel')),
          ),
          TvActivatable(
            onTap: () => Navigator.of(ctx).pop(true),
            builder: (onTap) =>
                FilledButton(onPressed: onTap, child: const Text('Remove')),
          ),
        ],
      ),
    );

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
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
      ..showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = _network;
    final isTv = PlatformHelper.isTV(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Power User Tools'),
        actions: [
          TvActivatable(
            onTap: _refresh,
            builder: (onTap) => IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
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
            title: 'Network',
            description: 'How this device is connected right now. Useful '
                'when a provider has trouble reaching you — for example to '
                'check which address it sees, or that your VPN is on.'
                '${isTv ? '' : ' Tap an address to copy it.'}',
            children: net == null
                ? const [
                    ListTile(
                      leading: IconBadge(icon: Icons.wifi_find_outlined),
                      title: Text('Checking your connection…'),
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
                      label: 'Connection',
                      value: net.connectionLabel,
                    ),
                    _InfoRow(
                      icon: net.vpn ? Icons.vpn_lock : Icons.vpn_lock_outlined,
                      label: 'VPN',
                      value: net.vpn ? 'On' : 'Off',
                    ),
                    if (net.connected)
                      _InfoRow(
                        icon: Icons.router_outlined,
                        label: 'Device IP address',
                        value: net.orderedAddresses.isEmpty
                            ? 'Not available'
                            : net.orderedAddresses.join('\n'),
                        onTap: _copier('Device IP address',
                            net.orderedAddresses.firstOrNull),
                      ),
                    if (net.vpn && net.vpnAddresses.isNotEmpty)
                      _InfoRow(
                        icon: Icons.vpn_lock_outlined,
                        label: 'VPN address',
                        value: net.vpnAddresses.join('\n'),
                        onTap: _copier(
                            'VPN address', net.vpnAddresses.firstOrNull),
                      ),
                    if (net.connected) _publicIpRow(theme),
                    if (net.connected && net.dns.isNotEmpty)
                      _InfoRow(
                        icon: Icons.dns_outlined,
                        label: 'DNS servers',
                        value: net.dns.join('\n'),
                      ),
                  ],
          ),
          _vpnGroup(),
          _speedGroup(),
          _bufferGroup(),
        ],
      ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VPN
  // ---------------------------------------------------------------------------

  Widget _vpnGroup() {
    final theme = Theme.of(context);
    final profile = _vpnProfile;
    final st = _vpnStatus;
    final ovpn = _ovpn;
    final os = _ovpnStatus;
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final route = prefs?.vpnRoute ?? 'app';

    String wgText() {
      if (profile == null) {
        return 'Import a WireGuard profile (.conf file) from your VPN '
            'provider.';
      }
      final where = profile.endpoint == null ? '' : ' · ${profile.endpoint}';
      if (!st.up) return 'Off — ${profile.name}$where';
      final hs = st.lastHandshake;
      final ago = hs == null
          ? 'waiting for the server to answer'
          : 'server answered ${_ago(hs)}';
      return 'Connected — ${profile.name}$where\n'
          '↓ ${formatBytes(st.rxBytes)}  ↑ ${formatBytes(st.txBytes)} · $ago';
    }

    String ovpnText() {
      if (ovpn == null) {
        return 'Import an OpenVPN profile (.ovpn file) from your VPN '
            'provider.';
      }
      final where = ovpn.endpoint == null ? '' : ' · ${ovpn.endpoint}';
      return switch (os.state) {
        'connected' => 'Connected — ${ovpn.name}$where\n'
            '↓ ${formatBytes(os.rxBytes)}  ↑ ${formatBytes(os.txBytes)}',
        'connecting' => 'Connecting — ${ovpn.name}$where',
        'error' => "Couldn't connect — ${ovpn.name}$where",
        _ => 'Off — ${ovpn.name}$where',
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
      description: 'A built-in VPN — WireGuard or OpenVPN. Handy when your '
          'internet provider blocks or slows down your IPTV provider. One '
          'connects at a time.',
      children: [
        _InfoRow(
          icon: st.up ? Icons.vpn_lock : Icons.vpn_key_outlined,
          label: 'WireGuard',
          value: wgText(),
          trailing: actionButton(
              profile == null
                  ? 'Import'
                  : st.up
                      ? 'Disconnect'
                      : 'Connect',
              profile == null ? _importVpn : _toggleVpn),
        ),
        _InfoRow(
          icon: os.up ? Icons.vpn_lock : Icons.lock_outline,
          label: 'OpenVPN',
          value: ovpnText(),
          trailing: actionButton(
              ovpn == null
                  ? 'Import'
                  : ovpnOn
                      ? 'Disconnect'
                      : 'Connect',
              ovpn == null ? _importOpenVpn : _toggleOpenVpn),
        ),
        if (profile != null || ovpn != null) ...[
          for (final (id, label, sub) in const [
            ('app', 'Only OpenIPTV', 'Other apps keep your normal connection'),
            ('device', 'Whole device',
                'Every app uses the VPN, except Android Auto\'s car link'),
          ])
            TvActivatable(
              onTap: () async {
                await prefs?.setVpnRoute(id);
                if (!mounted) return;
                setState(() {});
                if (_vpnStatus.up || _ovpnStatus.up) {
                  _say('Reconnect the VPN to apply this.');
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
              title: const Text('Connect when OpenIPTV opens'),
              subtitle: Text('Uses the VPN you connected last',
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
                title: const Text('Remove WireGuard profile'),
                onTap: tap,
              ),
            ),
          if (ovpn != null && ovpn.user != null)
            TvActivatable(
              onTap: _changeOpenVpnLogin,
              builder: (tap) => ListTile(
                leading: const IconBadge(icon: Icons.password),
                title: const Text('Change OpenVPN login'),
                subtitle: Text('Signed in as ${ovpn.user}',
                    style: theme.textTheme.bodySmall),
                onTap: tap,
              ),
            ),
          if (ovpn != null)
            TvActivatable(
              onTap: _removeOpenVpn,
              builder: (tap) => ListTile(
                leading: const IconBadge(icon: Icons.delete_outline),
                title: const Text('Remove OpenVPN profile'),
                onTap: tap,
              ),
            ),
        ],
      ],
    );
  }

  static String _ago(DateTime t) {
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 5) return 'just now';
    if (s < 60) return '${s}s ago';
    return '${s ~/ 60} min ago';
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
                ? 'This playlist has nothing to test with yet.'
                : "Couldn't download from your provider. It may be busy, "
                    'or your plan may allow only one connection at a time.')
        : _SpeedRun(result: result));
  }

  Future<void> _testInternet() async {
    if (_provider.running || _internet.running) return;
    setState(() => _internet = const _SpeedRun(running: true));
    SpeedResult? result;
    try {
      result = await measureDownload(internetSpeedUrl(),
          onProgress: (m) => _live(m, provider: false));
    } catch (_) {}
    if (!mounted) return;
    setState(() => _internet = result == null
        ? const _SpeedRun(error: "Couldn't run the test. Check your "
            'connection and try again.')
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
    return SettingsGroup(
      title: 'Speed test',
      description: 'Measures how fast video arrives. The provider test uses '
          'one connection to your provider — if your plan allows only one '
          'at a time, stop watching on other devices first.',
      children: [
        _speedRow(
          icon: Icons.speed,
          label: 'Speed to your provider',
          idle: 'Downloads from the playlist you are browsing for a few '
              'seconds.',
          run: _provider,
          onRun: _testProvider,
        ),
        _speedRow(
          icon: Icons.language,
          label: 'General internet speed',
          idle: 'Downloads a test file from $kInternetSpeedHost.',
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
    final r = run.result;
    final String value;
    if (run.running) {
      value = run.liveMbps == null
          ? 'Connecting…'
          : 'Testing… ${run.liveMbps!.toStringAsFixed(1)} Mbit/s';
    } else if (r != null) {
      value = '${r.mbps.toStringAsFixed(1)} Mbit/s — ${r.verdict}\n'
          'Response time ${r.firstByte.inMilliseconds} ms'
          '${r.paced ? '\nMeasured on a live channel, which arrives at '
              'playback speed — this shows it keeps up, not your top '
              'speed.' : ''}';
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
          child: Text(r == null && run.error == null ? 'Run' : 'Run again'),
        ),
      ),
    );
  }

  Widget _bufferGroup() {
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final current = BufferPreset.fromId(prefs?.bufferPreset);
    return SettingsGroup(
      title: 'Playback buffer',
      description: 'How much video the player keeps in reserve. A bigger '
          'reserve rides out a shaky connection but takes longer to start. '
          'Applies from the next channel or video you open.',
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
              title: Text(preset.label),
              subtitle: Text(preset.description,
                  style: Theme.of(context).textTheme.bodySmall),
              onTap: tap,
            ),
          ),
      ],
    );
  }

  Widget _publicIpRow(ThemeData theme) {
    final ip = _publicIp;
    final String value;
    if (_checkingPublicIp) {
      value = 'Checking…';
    } else if (ip != null) {
      value = ip;
    } else if (_publicIpFailed) {
      value = "Couldn't check right now. Try again.";
    } else {
      value = 'The address your provider sees. Checking asks '
          '$kPublicIpService.';
    }
    return _InfoRow(
      icon: Icons.public,
      label: 'Public IP address',
      value: value,
      onTap: _copier('Public IP address', ip),
      // Stays enabled (a no-op while checking): disabling it removed the
      // remote's focus, which jumped to another row.
      trailing: TvActivatable(
        onTap: _checkingPublicIp ? () {} : _checkPublicIp,
        builder: (onTap) => TextButton(
          onPressed: onTap,
          child: Text(ip == null ? 'Check' : 'Check again'),
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
  });

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
