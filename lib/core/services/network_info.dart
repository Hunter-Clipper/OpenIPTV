import 'dart:async';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// How the device is connected right now (Settings → Power User Tools).
class NetworkInfo {
  const NetworkInfo({
    required this.transport,
    this.vpn = false,
    this.addresses = const [],
    this.dns = const [],
  });

  factory NetworkInfo.fromMap(Map<Object?, Object?> m) => NetworkInfo(
        transport: m['transport'] as String? ?? 'none',
        vpn: m['vpn'] as bool? ?? false,
        // Link-local IPv6 (fe80::…) only means something on the local link.
        addresses: [
          for (final a in (m['addresses'] as List?) ?? const [])
            if (a is String && !a.toLowerCase().startsWith('fe80')) a,
        ],
        dns: [
          for (final a in (m['dns'] as List?) ?? const [])
            if (a is String) a,
        ],
      );

  /// 'wifi' | 'ethernet' | 'cellular' | 'other' | 'none'.
  final String transport;
  final bool vpn;

  /// The device's own addresses on the active network.
  final List<String> addresses;
  final List<String> dns;

  bool get connected => transport != 'none';

  String get connectionLabel => switch (transport) {
        'wifi' => 'Wi-Fi',
        'ethernet' => 'Ethernet',
        'cellular' => 'Mobile data',
        'none' => 'Not connected',
        _ => 'Connected',
      };

  /// IPv4 first: it's what people recognise and what most providers log.
  List<String> get orderedAddresses => [
        ...addresses.where(_isIpv4),
        ...addresses.where((a) => !_isIpv4(a)),
      ];

  static bool _isIpv4(String a) => !a.contains(':');
}

const _channel = MethodChannel('openiptv/device');

/// The active connection as Android reports it; "none" if it can't be read.
Future<NetworkInfo> readNetworkInfo() async {
  try {
    final m = await _channel.invokeMethod<Map<Object?, Object?>>('networkInfo');
    return m == null
        ? const NetworkInfo(transport: 'none')
        : NetworkInfo.fromMap(m);
  } catch (_) {
    return const NetworkInfo(transport: 'none');
  }
}

/// Where the public address comes from — named in the app, since it's the
/// one request in Power User Tools that leaves for a third party.
const kPublicIpService = 'api.ipify.org';

/// The address providers see (after the router / carrier / VPN). Only ever
/// called when the user taps Check. Null if it can't be found.
Future<String?> fetchPublicIp({http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final res = await c
        .get(Uri.https(kPublicIpService, '/'))
        .timeout(const Duration(seconds: 8));
    final ip = res.body.trim();
    if (res.statusCode != 200 || !_looksLikeIp(ip)) return null;
    return ip;
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}

bool _looksLikeIp(String s) =>
    RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(s) ||
    (s.contains(':') && RegExp(r'^[0-9a-fA-F:]+$').hasMatch(s));
