import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/services/buffer_preset.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/network_info.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/services/speed_test.dart';
import 'package:open_iptv/core/storage/preferences.dart';
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

  @override
  void initState() {
    super.initState();
    _refresh();
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
                    if (net.connected) _publicIpRow(theme),
                    if (net.connected && net.dns.isNotEmpty)
                      _InfoRow(
                        icon: Icons.dns_outlined,
                        label: 'DNS servers',
                        value: net.dns.join('\n'),
                      ),
                  ],
          ),
          _speedGroup(),
          _bufferGroup(),
        ],
      ),
    );
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
