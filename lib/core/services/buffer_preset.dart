import 'package:open_iptv/l10n/gen/app_localizations.dart';

/// How much the player buffers (Settings → Power User Tools, #41).
///
/// Each preset sets the native player's buffer *and* how patient the stream
/// watchdog is: a bigger buffer takes longer to refill after a hiccup, and
/// reconnecting while it refills would throw the buffer away.
enum BufferPreset {
  /// Starts and recovers quickly (the app's long-standing default).
  fast(
    id: 'fast',
    freezeLimit: Duration(seconds: 4),
    connectLimit: Duration(seconds: 8),
  ),

  balanced(
    id: 'balanced',
    freezeLimit: Duration(seconds: 7),
    connectLimit: Duration(seconds: 11),
  ),

  /// Keeps a much larger reserve; slower to start.
  smooth(
    id: 'smooth',
    freezeLimit: Duration(seconds: 12),
    connectLimit: Duration(seconds: 16),
  );

  const BufferPreset({
    required this.id,
    required this.freezeLimit,
    required this.connectLimit,
  });

  /// Stored in prefs and sent to the native player.
  final String id;

  /// Watchdog: how long a stream that was playing may sit still before
  /// it's reconnected, and how long a new connection gets to start.
  final Duration freezeLimit;
  final Duration connectLimit;

  static BufferPreset fromId(String? id) => BufferPreset.values
      .firstWhere((p) => p.id == id, orElse: () => BufferPreset.fast);
}

/// The words shown for a [BufferPreset] (names and one-line descriptions).
extension BufferPresetText on BufferPreset {
  String label(AppLocalizations l10n) => switch (this) {
        BufferPreset.fast => l10n.bufferPresetFastLabel,
        BufferPreset.balanced => l10n.bufferPresetBalancedLabel,
        BufferPreset.smooth => l10n.bufferPresetSmoothLabel,
      };

  String description(AppLocalizations l10n) => switch (this) {
        BufferPreset.fast => l10n.bufferPresetFastDescription,
        BufferPreset.balanced => l10n.bufferPresetBalancedDescription,
        BufferPreset.smooth => l10n.bufferPresetSmoothDescription,
      };
}
