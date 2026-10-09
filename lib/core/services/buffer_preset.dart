/// How much the player buffers (Settings → Power User Tools, #41).
///
/// Each preset sets the native player's buffer *and* how patient the stream
/// watchdog is: a bigger buffer takes longer to refill after a hiccup, and
/// reconnecting while it refills would throw the buffer away.
enum BufferPreset {
  /// Starts and recovers quickly (the app's long-standing default).
  fast(
    id: 'fast',
    label: 'Fast start',
    description: 'Starts quickly and resumes right after a short hiccup. '
        'Best on a good connection.',
    freezeLimit: Duration(seconds: 4),
    connectLimit: Duration(seconds: 8),
  ),

  balanced(
    id: 'balanced',
    label: 'Balanced',
    description: 'Waits a little longer before starting, for fewer '
        'interruptions on an average connection.',
    freezeLimit: Duration(seconds: 7),
    connectLimit: Duration(seconds: 11),
  ),

  /// Keeps a much larger reserve; slower to start.
  smooth(
    id: 'smooth',
    label: 'Smooth',
    description: 'Keeps a bigger reserve so playback rides out an unsteady '
        'connection. Slower to start and to change channels.',
    freezeLimit: Duration(seconds: 12),
    connectLimit: Duration(seconds: 16),
  );

  const BufferPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.freezeLimit,
    required this.connectLimit,
  });

  /// Stored in prefs and sent to the native player.
  final String id;
  final String label;
  final String description;

  /// Watchdog: how long a stream that was playing may sit still before
  /// it's reconnected, and how long a new connection gets to start.
  final Duration freezeLimit;
  final Duration connectLimit;

  static BufferPreset fromId(String? id) => BufferPreset.values
      .firstWhere((p) => p.id == id, orElse: () => BufferPreset.fast);
}
