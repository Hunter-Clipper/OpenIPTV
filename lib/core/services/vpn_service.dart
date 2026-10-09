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

/// A saved OpenVPN profile (.ovpn) and, when it needs one, the login.
class OpenVpnProfile {
  const OpenVpnProfile({
    required this.name,
    required this.config,
    this.user,
    this.pass,
  });
  final String name;

  /// The `.ovpn` text — may hold keys; secure storage only.
  final String config;
  final String? user;
  final String? pass;

  /// The server ("remote host port") of the first remote line.
  String? get endpoint {
    for (final line in const LineSplitter().convert(config)) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts.first == 'remote') {
        return parts.length >= 3 ? '${parts[1]}:${parts[2]}' : parts[1];
      }
    }
    return null;
  }

  static bool looksLikeOpenVpn(String text) {
    final t = text.toLowerCase();
    return t.contains('remote ') &&
        (t.contains('client') || t.contains('<ca>') || t.contains('dev tun'));
  }
}

/// OpenVPN tunnel state.
class OpenVpnStatus {
  const OpenVpnStatus({
    this.state = 'off',
    this.error,
    this.rxBytes = 0,
    this.txBytes = 0,
  });

  factory OpenVpnStatus.fromMap(Map<Object?, Object?> m) => OpenVpnStatus(
        state: m['state'] as String? ?? 'off',
        error: m['error'] as String?,
        rxBytes: ((m['rx'] as num?)?.toInt() ?? 0).clamp(0, 1 << 62),
        txBytes: ((m['tx'] as num?)?.toInt() ?? 0).clamp(0, 1 << 62),
      );

  /// 'off' | 'connecting' | 'connected' | 'error'.
  final String state;
  final String? error;
  final int rxBytes;
  final int txBytes;

  bool get up => state == 'connected';
  bool get busy => state == 'connecting';
}

/// Built-in VPN (Settings → Power User Tools, #41): WireGuard and OpenVPN
/// (OpenVPN 3 core). One runs at a time.
class VpnService {
  VpnService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _channel = MethodChannel('openiptv/vpn');
  static const _kConfig = 'otv_vpn_wg_config_v1';
  static const _kName = 'otv_vpn_wg_name_v1';
  static const _kOvpnConfig = 'otv_vpn_ovpn_config_v1';
  static const _kOvpnName = 'otv_vpn_ovpn_name_v1';
  static const _kOvpnUser = 'otv_vpn_ovpn_user_v1';
  static const _kOvpnPass = 'otv_vpn_ovpn_pass_v1';

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

  // ---------------------------------------------------------------- OpenVPN

  Future<OpenVpnProfile?> loadOpenVpn() async {
    try {
      final config = await _storage.read(key: _kOvpnConfig);
      if (config == null || config.isEmpty) return null;
      return OpenVpnProfile(
        name: await _storage.read(key: _kOvpnName) ?? 'OpenVPN',
        config: config,
        user: await _storage.read(key: _kOvpnUser),
        pass: await _storage.read(key: _kOvpnPass),
      );
    } catch (e) {
      debugPrint('[OTV-vpn] OpenVPN profile unreadable: ${e.runtimeType}');
      return null;
    }
  }

  Future<void> saveOpenVpn(OpenVpnProfile p) async {
    await _storage.write(key: _kOvpnConfig, value: p.config);
    await _storage.write(key: _kOvpnName, value: p.name);
    if (p.user != null) await _storage.write(key: _kOvpnUser, value: p.user);
    if (p.pass != null) await _storage.write(key: _kOvpnPass, value: p.pass);
  }

  Future<void> deleteOpenVpn() async {
    await disconnectOpenVpn();
    for (final k in [_kOvpnConfig, _kOvpnName, _kOvpnUser, _kOvpnPass]) {
      await _storage.delete(key: k);
    }
  }

  /// null = usable; 'needs_login' = asks for a username and password;
  /// else a plain reason it can't be used.
  Future<String?> validateOpenVpn(String config) async {
    if (!OpenVpnProfile.looksLikeOpenVpn(config)) {
      return "This isn't an OpenVPN profile.";
    }
    try {
      final r = await _channel
          .invokeMethod<String>('ovpnValidate', {'config': config});
      if (r == null || r.isEmpty) return null;
      if (r == 'needs_login') return 'needs_login';
      if (r == 'external_pki') {
        return 'This profile needs a certificate stored on the device, '
            "which OpenIPTV doesn't support.";
      }
      return 'This profile has a problem ($r).';
    } on MissingPluginException {
      return 'VPN is not available on this device.';
    } on PlatformException {
      return "Couldn't read this profile.";
    }
  }

  /// 'ok' (starting), 'denied' or 'error'.
  Future<String> connectOpenVpn(OpenVpnProfile p,
      {required String route}) async {
    try {
      return await _channel.invokeMethod<String>('ovpnConnect', {
            'config': p.config,
            'user': p.user,
            'pass': p.pass,
            'route': route,
          }) ??
          'error';
    } catch (_) {
      return 'error';
    }
  }

  Future<void> disconnectOpenVpn() async {
    try {
      await _channel.invokeMethod<String>('ovpnDisconnect');
    } catch (_) {}
  }

  Future<OpenVpnStatus> openVpnStatus() async {
    try {
      final m = await _channel.invokeMethod<Object?>('ovpnStatus');
      return m is Map ? OpenVpnStatus.fromMap(m) : const OpenVpnStatus();
    } catch (_) {
      return const OpenVpnStatus();
    }
  }

  /// "Connect when OpenIPTV opens": quietly brings up the VPN that was last
  /// connected. Never prompts — if Android hasn't allowed the VPN yet, it
  /// just skips.
  Future<void> autoConnect(AppPreferences prefs) async {
    if (!prefs.vpnAutoConnect) return;
    if (prefs.vpnKind == 'openvpn') {
      final p = await loadOpenVpn();
      if (p == null || (await openVpnStatus()).state != 'off') return;
      debugPrint('[OTV-vpn] auto-connect openvpn: '
          '${await connectOpenVpn(p, route: prefs.vpnRoute)}');
      return;
    }
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
      'starting' => 'Connecting the VPN…',
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
