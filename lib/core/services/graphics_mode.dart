import 'package:flutter/services.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';

const _channel = MethodChannel('openiptv/device');

/// How the app draws itself and the video (Settings → Power User Tools →
/// Graphics mode, #157).
///
/// On some TVs Flutter's default graphics path puts torn frames on screen
/// (measured on an Amlogic S7D Mi TV; see `GraphicsMode.kt`). The setting is
/// kept natively — it has to be known before the first screen is drawn — and
/// applies the next time the app starts.
enum GraphicsModeSetting {
  automatic(
    id: 'auto',
  ),
  standard(
    id: 'standard',
  ),
  compatibility(
    id: 'compat',
  );

  const GraphicsModeSetting({required this.id});

  /// Stored natively and sent over the channel.
  final String id;

  static GraphicsModeSetting fromId(String? id) => values
      .firstWhere((m) => m.id == id, orElse: () => GraphicsModeSetting.automatic);
}

/// The words shown for a [GraphicsModeSetting].
extension GraphicsModeSettingText on GraphicsModeSetting {
  String label(AppLocalizations l10n) => switch (this) {
        GraphicsModeSetting.automatic => l10n.graphicsModeAutomaticLabel,
        GraphicsModeSetting.standard => l10n.graphicsModeStandardLabel,
        GraphicsModeSetting.compatibility => l10n.graphicsModeCompatibleLabel,
      };

  String description(AppLocalizations l10n) => switch (this) {
        GraphicsModeSetting.automatic => l10n.graphicsModeAutomaticDescription,
        GraphicsModeSetting.standard => l10n.graphicsModeStandardDescription,
        GraphicsModeSetting.compatibility =>
          l10n.graphicsModeCompatibleDescription,
      };
}

/// What the native side reports about the graphics mode.
class GraphicsModeInfo {
  const GraphicsModeInfo({
    required this.setting,
    required this.active,
    required this.autoWouldUse,
    this.socModel,
    this.boardPlatform,
  });

  /// What the user picked.
  final GraphicsModeSetting setting;

  /// What this run of the app is using (`standard` or `compat`). It differs
  /// from the setting until the app is restarted.
  final String active;

  /// What Automatic resolves to on this device.
  final String autoWouldUse;

  final String? socModel;
  final String? boardPlatform;

  /// The mode [setting] asks for on this device.
  String get wanted => switch (setting) {
        GraphicsModeSetting.automatic => autoWouldUse,
        GraphicsModeSetting.standard => 'standard',
        GraphicsModeSetting.compatibility => 'compat',
      };

  /// The setting changed since the app started: a restart applies it.
  bool get needsRestart => wanted != active;

  /// "Amlogic S905X5M (s7d)" style line for the screen and bug reports.
  String? get chip {
    final parts = <String>[
      if (socModel != null && socModel!.isNotEmpty) socModel!,
      if (boardPlatform != null && boardPlatform!.isNotEmpty) boardPlatform!,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static GraphicsModeInfo? fromMap(Object? raw) {
    if (raw is! Map) return null;
    return GraphicsModeInfo(
      setting: GraphicsModeSetting.fromId(raw['setting'] as String?),
      active: raw['active'] as String? ?? 'standard',
      autoWouldUse: raw['autoWouldUse'] as String? ?? 'standard',
      socModel: raw['socModel'] as String?,
      boardPlatform: raw['boardPlatform'] as String?,
    );
  }
}

/// Whether Settings shows the Graphics mode group. TVs only: phones and
/// tablets never see it (and the native side ignores it there). Also hidden
/// where there is no native side to ask (tests, web).
bool showGraphicsMode({required bool isTv, required GraphicsModeInfo? info}) =>
    isTv && info != null;

/// The current graphics mode, or null where there's no native side (tests,
/// web, other platforms).
Future<GraphicsModeInfo?> graphicsModeInfo() async {
  try {
    return GraphicsModeInfo.fromMap(
        await _channel.invokeMethod<Object>('graphicsInfo'));
  } catch (_) {
    return null;
  }
}

/// Saves [mode]; it applies after a restart. Returns the new state.
Future<GraphicsModeInfo?> setGraphicsMode(GraphicsModeSetting mode) async {
  try {
    return GraphicsModeInfo.fromMap(
        await _channel.invokeMethod<Object>('setGraphicsMode', {'mode': mode.id}));
  } catch (_) {
    return null;
  }
}

/// Restarts the app so a new graphics mode takes effect. False if it
/// couldn't.
Future<bool> restartApp() async {
  try {
    return await _channel.invokeMethod<bool>('restartApp') ?? false;
  } catch (_) {
    return false;
  }
}
