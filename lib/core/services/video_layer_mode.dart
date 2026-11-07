import 'package:flutter/services.dart';

const _channel = MethodChannel('openiptv/device');

/// Whether this run of the app shows the main player's video on the real
/// video layer behind Flutter (TVs only, #162). Set once at start-up from
/// what the native side started with; a settings change applies after a
/// restart, so this never flips while the app runs.
bool videoLayerActive = false;

/// Settings → Power User Tools → Video layer.
enum VideoLayerSetting {
  automatic(
    id: 'auto',
    label: 'Automatic',
    description: 'Shows the picture the way TV players do, for smoother '
        'video and faster, cleaner switching. Recommended.',
  ),
  on(
    id: 'on',
    label: 'On',
    description: 'Always use it on this TV.',
  ),
  off(
    id: 'off',
    label: 'Off',
    description: 'Draw the picture inside the app, as before. Try this if '
        'the picture is ever missing or wrong.',
  );

  const VideoLayerSetting(
      {required this.id, required this.label, required this.description});

  final String id;
  final String label;
  final String description;

  static VideoLayerSetting fromId(String? id) => values
      .firstWhere((m) => m.id == id, orElse: () => VideoLayerSetting.automatic);
}

class VideoLayerInfo {
  const VideoLayerInfo(
      {required this.setting, required this.active, required this.wanted});

  final VideoLayerSetting setting;

  /// This run started with the layer.
  final bool active;

  /// The setting asks for the layer on this device.
  final bool wanted;

  bool get needsRestart => wanted != active;

  static VideoLayerInfo? fromMap(Object? raw) {
    if (raw is! Map) return null;
    return VideoLayerInfo(
      setting: VideoLayerSetting.fromId(raw['setting'] as String?),
      active: raw['active'] as bool? ?? false,
      wanted: raw['wanted'] as bool? ?? false,
    );
  }
}

/// The current state, or null where there's no native side (tests, web).
Future<VideoLayerInfo?> videoLayerInfo() async {
  try {
    return VideoLayerInfo.fromMap(
        await _channel.invokeMethod<Object>('videoLayerInfo'));
  } catch (_) {
    return null;
  }
}

/// Saves [mode]; it applies after a restart.
Future<VideoLayerInfo?> setVideoLayerMode(VideoLayerSetting mode) async {
  try {
    return VideoLayerInfo.fromMap(await _channel
        .invokeMethod<Object>('setVideoLayerMode', {'mode': mode.id}));
  } catch (_) {
    return null;
  }
}
