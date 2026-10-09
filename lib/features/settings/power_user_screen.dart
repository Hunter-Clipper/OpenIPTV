import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_iptv/core/services/network_info.dart';
import 'package:open_iptv/shared/widgets/settings_group.dart';
import 'package:open_iptv/shared/widgets/tv_focusable.dart';
import 'package:open_iptv/ui/platform_helper.dart';

/// Settings → Advanced → Power User Tools (#41). Phase 1: what the device's
/// connection looks like right now, for diagnosing provider problems.
class PowerUserScreen extends StatefulWidget {
  const PowerUserScreen({super.key});

  @override
  State<PowerUserScreen> createState() => _PowerUserScreenState();
}

class _PowerUserScreenState extends State<PowerUserScreen> {
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
        ],
      ),
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
