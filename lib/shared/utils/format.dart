import 'dart:ui' show Locale;

import 'package:intl/intl.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';

/// `h:mm:ss`, or `m:ss` under an hour (`0:33`, `12:05`) — for playback
/// positions, matching how mainstream players show time.
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// `1h 5m` (`1h` on the hour), or `45m` under an hour — for runtimes.
/// [padMinutes] renders `1h 05m` / `05m` instead.
String formatRuntime(Duration d, {bool padMinutes = false}) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final mm = padMinutes ? m.toString().padLeft(2, '0') : '$m';
  if (h > 0) return m == 0 && !padMinutes ? '${h}h' : '${h}h ${mm}m';
  return padMinutes ? '${mm}m' : '${d.inMinutes}m';
}

/// Like [formatRuntime] but with the unit letters of the app language
/// (`1 h 5 min` in Spanish).
String formatRuntimeL10n(AppLocalizations l10n, Duration d,
    {bool padMinutes = false}) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final mm = padMinutes ? m.toString().padLeft(2, '0') : '$m';
  if (h > 0) {
    return m == 0 && !padMinutes
        ? l10n.formatRuntimeHours(h)
        : l10n.formatRuntimeHoursMinutes(h, mm);
  }
  return l10n.formatRuntimeMinutes(padMinutes ? mm : '${d.inMinutes}');
}

/// A short date in the order and style of [locale] (`11/12/2026`,
/// `12/11/2026`). Use [formatYmd] for file names and anything stored.
String formatDate(DateTime d, Locale locale) =>
    DateFormat.yMd(locale.toLanguageTag()).format(d);

/// `YYYY-MM-DD` in the date's own timezone.
String formatYmd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Provider ratings arrive as free text (`7.733`, `8`, `PG-13`); numeric
/// ones are shown to one decimal place, anything else as-is.
String formatRating(String rating) {
  final value = double.tryParse(rating.trim());
  return value == null ? rating : value.toStringAsFixed(1);
}
