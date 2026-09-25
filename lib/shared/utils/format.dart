/// `h:mm:ss`, or `m:ss` under an hour (`0:33`, `12:05`) — for playback
/// positions, matching how mainstream players show time.
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// `1h 5m`, or `45m` under an hour — for runtimes.
/// [padMinutes] renders `1h 05m` / `05m` instead.
String formatRuntime(Duration d, {bool padMinutes = false}) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final mm = padMinutes ? m.toString().padLeft(2, '0') : '$m';
  if (h > 0) return '${h}h ${mm}m';
  return padMinutes ? '${mm}m' : '${d.inMinutes}m';
}

/// `YYYY-MM-DD` in the date's own timezone.
String formatYmd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Provider ratings arrive as free text (`7.733`, `8`, `PG-13`); numeric
/// ones are shown to one decimal place, anything else as-is.
String formatRating(String rating) {
  final value = double.tryParse(rating.trim());
  return value == null ? rating : value.toStringAsFixed(1);
}
