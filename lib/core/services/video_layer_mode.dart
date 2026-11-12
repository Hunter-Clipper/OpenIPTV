import 'package:flutter/services.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';

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
  ),
  on(
    id: 'on',
  ),
  off(
    id: 'off',
  );

  const VideoLayerSetting({required this.id});

  final String id;

  static VideoLayerSetting fromId(String? id) => values
      .firstWhere((m) => m.id == id, orElse: () => VideoLayerSetting.automatic);
}

/// The words shown for a [VideoLayerSetting].
extension VideoLayerSettingText on VideoLayerSetting {
  String label(AppLocalizations l10n) => switch (this) {
        VideoLayerSetting.automatic => l10n.videoLayerAutomaticLabel,
        VideoLayerSetting.on => l10n.videoLayerOnLabel,
        VideoLayerSetting.off => l10n.videoLayerOffLabel,
      };

  String description(AppLocalizations l10n) => switch (this) {
        VideoLayerSetting.automatic => l10n.videoLayerAutomaticDescription,
        VideoLayerSetting.on => l10n.videoLayerOnDescription,
        VideoLayerSetting.off => l10n.videoLayerOffDescription,
      };
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

/// Works out whether this run has the video layer, for [videoLayerActive].
///
/// Dart can start before the activity exists (the engine is shared with the
/// media session), and then native says "not active" or the channel isn't
/// there yet. A wrong "no" leaves the picture in a one-pixel layer while the
/// audio plays, so wait (up to 3 s) until native has caught up with what the
/// setting asks for, then tell native Dart is drawing for the layer.
Future<bool> resolveVideoLayerActive() async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  VideoLayerInfo? info;
  while (true) {
    info = await videoLayerInfo();
    if (info != null && (info.active || !info.wanted)) break;
    if (DateTime.now().isAfter(deadline)) break;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  final active = info?.active ?? false;
  if (active) {
    try {
      await _channel.invokeMethod<Object>('videoLayerConfirm');
    } catch (_) {}
  }
  return active;
}
