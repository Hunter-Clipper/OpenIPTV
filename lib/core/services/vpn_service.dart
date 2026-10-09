import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:open_iptv/core/storage/preferences.dart';

/// What the tunnel is doing right now.
class VpnStatus {
  const VpnStatus({
    this.up = false,
    this.rxBytes = 0,
    this.txBytes = 0,
    this.lastHandshake,
  });

  factory VpnStatus.fromMap(Map<Object?, Object?> m) {
    final hs = (m['handshake'] as num?)?.toInt() ?? 0;
    return VpnStatus(
      up: m['up'] == true,
      rxBytes: (m['rx'] as num?)?.toInt() ?? 0,
      txBytes: (m['tx'] as num?)?.toInt() ?? 0,
      lastHandshake:
          hs > 0 ? DateTime.fromMillisecondsSinceEpoch(hs) : null,
    );
  }

  final bool up;
  final int rxBytes;
  final int txBytes;

  /// When the server last answered — none yet means it isn't reaching it.
  final DateTime? lastHandshake;
}

/// A saved WireGuard profile.
class VpnProfile {
  const VpnProfile({required this.name, required this.config});
  final String name;

  /// The `.conf` text. Holds a private key — kept in secure storage only.
  final String config;

  /// The server it connects to ("Endpoint" of the first peer), for display.
  String? get endpoint {
    for (final line in const LineSplitter().convert(config)) {
      final t = line.trim();
      final eq = t.indexOf('=');
      if (eq > 0 && t.substring(0, eq).trim().toLowerCase() == 'endpoint') {
        return t.substring(eq + 1).trim();
      }
    }
    return null;
  }

  /// Quick shape check before the native parser sees it.
  static bool looksLikeWireGuard(String text) {
    final t = text.toLowerCase();
    return t.contains('[interface]') &&
        t.contains('privatekey') &&
        t.contains('[peer]');
  }
}

/// Built-in WireGuard VPN (Settings → Power User Tools, #41).
class VpnService {
  VpnService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _channel = MethodChannel('openiptv/vpn');
  static const _kConfig = 'otv_vpn_wg_config_v1';
  static const _kName = 'otv_vpn_wg_name_v1';

  final FlutterSecureStorage _storage;

  Future<VpnProfile?> loadProfile() async {
    try {
      final config = await _storage.read(key: _kConfig);
      if (config == null || config.isEmpty) return null;
      final name = await _storage.read(key: _kName);
      return VpnProfile(name: name ?? 'WireGuard', config: config);
    } catch (e) {
      debugPrint('[OTV-vpn] profile unreadable: ${e.runtimeType}');
      return null;
    }
  }

  Future<void> saveProfile(VpnProfile p) async {
    await _storage.write(key: _kConfig, value: p.config);
    await _storage.write(key: _kName, value: p.name);
  }

  Future<void> deleteProfile() async {
    await disconnect();
    await _storage.delete(key: _kConfig);
    await _storage.delete(key: _kName);
  }

  /// Null when [config] is a usable WireGuard profile, else why not.
  Future<String?> validate(String config) async {
    if (!VpnProfile.looksLikeWireGuard(config)) {
      return "This isn't a WireGuard profile.";
    }
    try {
      final problem = await _channel
          .invokeMethod<String>('validate', {'config': config});
      return problem == null ? null : "This profile has a problem ($problem).";
    } on MissingPluginException {
      return 'VPN is not available on this device.';
    }
  }

  /// 'ok', 'denied' (the user refused the VPN prompt), 'bad_config' or
  /// 'error'. [route]: 'app' (only OpenIPTV) or 'device'.
  Future<String> connect(VpnProfile p, {required String route}) async {
    try {
      return await _channel.invokeMethod<String>(
              'connect', {'config': p.config, 'route': route}) ??
          'error';
    } on PlatformException {
      return 'error';
    } on MissingPluginException {
      return 'error';
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod<String>('disconnect');
    } catch (_) {}
  }

  Future<VpnStatus> status() async {
    try {
      final m = await _channel.invokeMethod<Object?>('status');
      return m is Map ? VpnStatus.fromMap(m) : const VpnStatus();
    } catch (_) {
      return const VpnStatus();
    }
  }

  /// "Connect when OpenIPTV opens": quietly brings the tunnel up at start.
  /// Never prompts — if Android hasn't allowed the VPN yet, it just skips.
  Future<void> autoConnect(AppPreferences prefs) async {
    if (!prefs.vpnAutoConnect) return;
    final profile = await loadProfile();
    if (profile == null) return;
    if ((await status()).up) return;
    final r = await connect(profile, route: prefs.vpnRoute);
    debugPrint('[OTV-vpn] auto-connect: $r');
  }
}

/// Plain-English message for a [VpnService.connect] result.
String vpnConnectMessage(String result) => switch (result) {
      'ok' => 'VPN connected',
      'denied' => 'OpenIPTV needs your permission to set up a VPN. '
          'Tap Connect and allow it.',
      'bad_config' => 'This profile has a problem. Import it again.',
      _ => "Couldn't connect the VPN. Check the profile and try again.",
    };

String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}
