import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/vpn_service.dart';

// A made-up profile: keys are random base64, not anyone's real keys.
const _conf = '''
[Interface]
PrivateKey = yAnz5TF+lXXJte14tji3zlMNq+hd2rYUIgJBgB3fBmk=
Address = 10.2.0.2/32
DNS = 10.2.0.1

[Peer]
PublicKey = xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=
AllowedIPs = 0.0.0.0/0
Endpoint = vpn.example.net:51820
''';

void main() {
  test('recognises a WireGuard profile and finds its server', () {
    expect(VpnProfile.looksLikeWireGuard(_conf), isTrue);
    expect(const VpnProfile(name: 'x', config: _conf).endpoint,
        'vpn.example.net:51820');
  });

  test('other files are not mistaken for one', () {
    expect(VpnProfile.looksLikeWireGuard('client\ndev tun\nremote x 1194'),
        isFalse);
    expect(VpnProfile.looksLikeWireGuard('#EXTM3U'), isFalse);
    expect(const VpnProfile(name: 'x', config: '[Interface]').endpoint,
        isNull);
  });

  test('tunnel status from the native map', () {
    final up = VpnStatus.fromMap({
      'up': true,
      'rx': 2048,
      'tx': 512,
      'handshake': 1760000000000,
    });
    expect(up.up, isTrue);
    expect(up.rxBytes, 2048);
    expect(up.lastHandshake, isNotNull);
    final noHandshake = VpnStatus.fromMap({'up': true, 'handshake': 0});
    expect(noHandshake.lastHandshake, isNull);
    expect(VpnStatus.fromMap({}).up, isFalse);
  });

  test('sizes read naturally', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
  });

  test('connect results in plain English', () {
    expect(vpnConnectMessage('ok'), 'VPN connected');
    expect(vpnConnectMessage('denied'), contains('permission'));
    expect(vpnConnectMessage('anything'), contains("Couldn't connect"));
  });
}
