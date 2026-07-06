import 'package:flutter/services.dart';

const MethodChannel _pipChannel = MethodChannel('openiptv/pip');

/// Wires the platform channel `MainActivity` uses to report when the PiP
/// window's active state changes. Call once from `app.dart` after
/// preferences are loaded.
void initPipChannel({
  required void Function(bool isInPip) onPipModeChanged,
}) {
  _pipChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'onPipModeChanged':
        onPipModeChanged(call.arguments as bool);
        return null;
      default:
        return null;
    }
  });
}

/// Pushes whether Home-press should currently trigger Picture-in-Picture.
///
/// This must be pushed proactively rather than queried from native at
/// leave-hint time: `enterPictureInPictureMode()` has to be called
/// synchronously inside `onUserLeaveHint()`, before the activity is paused —
/// there's no time left for a round-trip back to Dart at that point, even a
/// fast one. So MainActivity keeps a cached flag, updated here whenever
/// PiP-eligibility (pref enabled AND actively playing) changes.
Future<void> updatePipAvailability(bool canEnterPip) async {
  await _pipChannel.invokeMethod('setPipAvailable', canEnterPip);
}
