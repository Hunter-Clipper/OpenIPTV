import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_iptv/core/services/network_info.dart';

void main() {
  test('reads the native map; IPv4 first, link-local IPv6 dropped', () {
    final info = NetworkInfo.fromMap({
      'transport': 'wifi',
      'vpn': true,
      'addresses': ['2600:1700::5', 'fe80::1', '10.0.1.39'],
      'dns': ['10.0.1.1', 8],
    });
    expect(info.connectionLabel, 'Wi-Fi');
    expect(info.vpn, isTrue);
    expect(info.orderedAddresses, ['10.0.1.39', '2600:1700::5']);
    expect(info.dns, ['10.0.1.1']);
    expect(info.connected, isTrue);
  });

  test('connection labels in plain English', () {
    String label(String t) => NetworkInfo(transport: t).connectionLabel;
    expect(label('ethernet'), 'Ethernet');
    expect(label('cellular'), 'Mobile data');
    expect(label('none'), 'Not connected');
    expect(label('other'), 'Connected');
    expect(const NetworkInfo(transport: 'none').connected, isFalse);
  });

  test('a missing or odd map reads as not connected', () {
    final info = NetworkInfo.fromMap({});
    expect(info.transport, 'none');
    expect(info.addresses, isEmpty);
  });

  group('public IP', () {
    test('returns the address the service reports', () async {
      final client = MockClient((req) async {
        expect(req.url.host, kPublicIpService);
        return http.Response('203.0.113.7\n', 200);
      });
      expect(await fetchPublicIp(client: client), '203.0.113.7');
    });

    test('accepts IPv6', () async {
      final client =
          MockClient((_) async => http.Response('2001:db8::42', 200));
      expect(await fetchPublicIp(client: client), '2001:db8::42');
    });

    test('anything else — an error page, a failure — gives null', () async {
      expect(
          await fetchPublicIp(
              client: MockClient(
                  (_) async => http.Response('<html>oops</html>', 200))),
          isNull);
      expect(
          await fetchPublicIp(
              client: MockClient((_) async => http.Response('', 503))),
          isNull);
      expect(
          await fetchPublicIp(
              client: MockClient((_) async => throw Exception('offline'))),
          isNull);
    });
  });

  test('a VPN keeps the real device address and lists its own', () {
    final info = NetworkInfo.fromMap({
      'transport': 'wifi',
      'vpn': true,
      'addresses': ['10.0.1.52'],
      'vpnAddresses': ['10.99.77.2'],
      'vpnDns': ['10.99.77.1'],
    });
    expect(info.orderedAddresses, ['10.0.1.52']);
    expect(info.vpnAddresses, ['10.99.77.2']);
    expect(info.vpnDns, ['10.99.77.1']);
  });
}
