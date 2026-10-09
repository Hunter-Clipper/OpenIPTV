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

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadVpn();
    // Live tunnel status (traffic, last handshake) while this screen is up.
    _vpnTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollVpn());
  }

  @override
  void dispose() {
    _vpnTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVpn() async {
    final p = await _vpn.loadProfile();
    if (!mounted) return;
    setState(() => _vpnProfile = p);
    await _pollVpn();
  }

  Future<void> _pollVpn() async {
    if (_vpnProfile == null) return;
    final st = await _vpn.status();
    if (!mounted) return;
    final changed = st.up != _vpnStatus.up;
    setState(() => _vpnStatus = st);
    // The connection details (VPN on/off, addresses) change with it.
    if (changed) unawaited(_refresh());
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
      final r = await _vpn.connect(profile, route: prefs?.vpnRoute ?? 'app');
      if (mounted) _say(vpnConnectMessage(r));
    }
    await _pollVpn();
    if (mounted) setState(() => _vpnBusy = false);
  }

  Future<void> _removeVpn() async {
    final ok = await showDialog<bool>(
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
    if (ok != true) return;
    await _vpn.deleteProfile();
    // Nothing left to auto-connect to.
    await ref.read(appPreferencesProvider).valueOrNull?.setVpnAutoConnect(false);
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
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
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
    );
  }

  // ---------------------------------------------------------------------------
  // VPN
  // ---------------------------------------------------------------------------

  Widget _vpnGroup() {
    final theme = Theme.of(context);
    final profile = _vpnProfile;
    final st = _vpnStatus;
    final prefs = ref.watch(appPreferencesProvider).valueOrNull;
    final route = prefs?.vpnRoute ?? 'app';

    String statusText() {
      if (profile == null) {
        return 'Import a WireGuard profile (.conf file) from your VPN '
            'provider to send OpenIPTV through it.';
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

    return SettingsGroup(
      title: 'VPN',
      description: 'A built-in WireGuard VPN. Handy when your internet '
          'provider blocks or slows down your IPTV provider.',
      children: [
        _InfoRow(
          icon: st.up ? Icons.vpn_lock : Icons.vpn_key_outlined,
          label: 'WireGuard',
          value: statusText(),
          trailing: TvActivatable(
            // A no-op while busy, so TV focus stays put.
            onTap: _vpnBusy
                ? () {}
                : (profile == null ? _importVpn : _toggleVpn),
            builder: (onTap) => TextButton(
              onPressed: onTap,
              child: Text(profile == null
                  ? 'Import'
                  : st.up
                      ? 'Disconnect'
                      : 'Connect'),
            ),
          ),
        ),
        if (profile != null) ...[
          for (final (id, label, sub) in const [
            ('app', 'Only OpenIPTV', 'Other apps keep your normal connection'),
            ('device', 'Whole device', 'Everything on this device uses the VPN'),
          ])
            TvActivatable(
              onTap: () async {
                await prefs?.setVpnRoute(id);
                if (!mounted) return;
                setState(() {});
                if (_vpnStatus.up) {
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
              value: prefs?.vpnAutoConnect ?? false,
              onChanged: tap == null ? null : (_) => tap(),
            ),
          ),
          TvActivatable(
            onTap: _removeVpn,
            builder: (tap) => ListTile(
              leading: const IconBadge(icon: Icons.delete_outline),
              title: const Text('Remove profile'),
              onTap: tap,
            ),
          ),
        ],
        const _InfoRow(
          icon: Icons.info_outline,
          label: 'OpenVPN',
          value: 'OpenVPN profiles (.ovpn) aren\'t built in yet. Import '
              'them into an OpenVPN app and choose "Whole device" there.',
        ),
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
    return TvActivatable(
      onTap: onTap,
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
