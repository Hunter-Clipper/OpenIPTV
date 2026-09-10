import 'package:flutter/services.dart';

const _channel = MethodChannel('openiptv/device');

/// Queries native Android for whether this device is running in TV mode
/// (`UiModeManager.currentModeType == UI_MODE_TYPE_TELEVISION`). Android-only
/// — always returns false on other platforms or if the channel call fails.
Future<bool> isTelevisionDevice() async {
  try {
    return await _channel.invokeMethod<bool>('isTelevision') ?? false;
  } catch (_) {
    return false;
  }
}
