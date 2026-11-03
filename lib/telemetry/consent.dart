// Consent for anonymous reports (#150). Nothing is recorded, queued or sent
// unless the stored choice is exactly 'on'. A new install has no choice yet.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preference key. Also read by the native crash handler (Kotlin) from
/// SharedPreferences as `flutter.stats_choice`, so keep the two in step.
const statsChoiceKey = 'stats_choice';

enum StatsChoice { unset, on, off }

StatsChoice parseStatsChoice(String? raw) => switch (raw) {
      'on' => StatsChoice.on,
      'off' => StatsChoice.off,
      _ => StatsChoice.unset,
    };

Future<StatsChoice> readStatsChoice() async {
  final p = await SharedPreferences.getInstance();
  return parseStatsChoice(p.getString(statsChoiceKey));
}

Future<void> writeStatsChoice(StatsChoice choice) async {
  final p = await SharedPreferences.getInstance();
  if (choice == StatsChoice.unset) {
    await p.remove(statsChoiceKey);
  } else {
    await p.setString(statsChoiceKey, choice.name);
  }
}

/// Runtime copy for the UI. Loaded at startup.
final statsChoiceProvider =
    StateProvider<StatsChoice>((ref) => StatsChoice.unset);
