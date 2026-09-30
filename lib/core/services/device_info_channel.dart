import 'package:flutter/services.dart';

const _channel = MethodChannel('openiptv/device');

/// Queries native Android for whether this device is running in TV mode
/// (`UiModeManager.currentModeType == UI_MODE_TYPE_TELEVISION`). Android-only
/// — returns false on other platforms or if the call fails.
///
/// The handler is registered in `MainActivity.configureFlutterEngine`, but
/// the engine is audio_service's shared one, which starts running Dart as
/// soon as it's created — before the activity attaches. On a slow device
/// `main()` can get here first, see [MissingPluginException] and wrongly
/// settle on the phone layout on a TV. So a missing handler is retried
/// (up to [timeout]) instead of being read as "not a TV".
Future<bool> isTelevisionDevice({
  Duration timeout = const Duration(seconds: 3),
  Duration retryEvery = const Duration(milliseconds: 50),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    try {
      return await _channel.invokeMethod<bool>('isTelevision') ?? false;
    } on MissingPluginException {
      if (DateTime.now().isAfter(deadline)) return false;
      await Future<void>.delayed(retryEvery);
    } catch (_) {
      return false;
    }
  }
}

/// Whether the device has a real document picker. Google TV / Fire TV often
/// don't (the request goes to a stub that cancels at once), so file pickers
/// need a fallback there. Assumes yes if the question can't be asked.
Future<bool> hasDocumentPicker() async {
  try {
    return await _channel.invokeMethod<bool>('hasDocumentPicker') ?? true;
  } catch (_) {
    return true;
  }
}
