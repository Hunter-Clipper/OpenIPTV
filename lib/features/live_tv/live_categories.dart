import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/services/parental_service.dart';

/// Live TV's browsable categories, in the order Live TV shows them:
/// first-appearance order (channels arrive in the provider's order), or A–Z.
/// Hidden categories are left out, adult ones too on a kids profile, and
/// anything [skip] matches (e.g. locked categories in the player's panel).
List<String> liveCategories(
  Iterable<Channel> channels, {
  Set<String> hidden = const {},
  bool isKid = false,
  bool az = false,
  bool Function(String category)? skip,
}) {
  final seen = <String>{};
  final cats = <String>[];
  for (final c in channels) {
    for (final cat in c.categories) {
      if (hidden.contains(cat) || !seen.add(cat)) continue;
      if (isKid && isAdultCategory(cat)) continue;
      if (skip != null && skip(cat)) continue;
      cats.add(cat);
    }
  }
  if (az) cats.sort();
  return cats;
}
