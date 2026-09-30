import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/epg_service.dart';

const _xml = '<?xml version="1.0" encoding="UTF-8"?><tv><channel id="a"/></tv>';

Future<String> _read(Stream<List<int>> s) =>
    maybeGunzip(s).transform(const Utf8Decoder()).join();

void main() {
  test('plain XML passes through untouched', () async {
    expect(await _read(Stream.value(utf8.encode(_xml))), _xml);
  });

  test('unlabelled gzip is unpacked', () async {
    final gz = gzip.encode(utf8.encode(_xml));
    expect(await _read(Stream.value(gz)), _xml);
  });

  test('gzip split into 1-byte chunks is still detected', () async {
    final gz = gzip.encode(utf8.encode(_xml));
    expect(await _read(Stream.fromIterable([for (final b in gz) [b]])), _xml);
  });

  test('empty body stays empty', () async {
    expect(await _read(const Stream.empty()), '');
  });
}
