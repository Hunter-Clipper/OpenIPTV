import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/services/device_info_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('openiptv/device');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('waits for a handler that registers late (slow TV start-up)',
      () async {
    // No handler yet: the call throws MissingPluginException…
    final result = isTelevisionDevice();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    // …until the activity attaches and registers it.
    messenger.setMockMethodCallHandler(channel, (_) async => true);
    expect(await result, isTrue);
  });

  test('gives up and assumes not-a-TV when no handler ever appears',
      () async {
    expect(
      await isTelevisionDevice(timeout: const Duration(milliseconds: 150)),
      isFalse,
    );
  });

  test('a real platform error means not-a-TV, without retrying', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      throw PlatformException(code: 'boom');
    });
    expect(await isTelevisionDevice(), isFalse);
    expect(calls, 1);
  });
}
