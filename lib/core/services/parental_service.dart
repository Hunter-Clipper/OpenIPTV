import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/storage/preferences.dart';

const List<String> _adultKeywords = [
  'xxx', 'adult', 'porn', 'erotic', '18+', 'x-rated', 'hentai',
];

/// Returns true if [name] matches known adult-content keywords.
bool isAdultCategory(String name) {
  final lower = name.toLowerCase();
  return _adultKeywords.any((kw) => lower.contains(kw));
}

/// Returns true if [name] should be behind the parental PIN gate.
/// A category is locked when parental protection is enabled AND either the
/// name is in the explicit locked list OR it matches adult keywords.
/// Unlocking requires an admin profile's PIN — see [ProfileService.verifyAnyAdminPin].
bool isCategoryLocked(
    String name, AppPreferences prefs, Set<String> sessionUnlocked) {
  if (!prefs.parentalProtectionEnabled) return false;
  if (sessionUnlocked.contains(name)) return false;
  return prefs.parentalLockedCategories.contains(name) ||
      isAdultCategory(name);
}

/// Categories unlocked for the current app session (cleared on restart).
final parentalSessionUnlockedProvider =
    StateProvider<Set<String>>((ref) => const {});
