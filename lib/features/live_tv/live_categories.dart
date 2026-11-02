import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/services/parental_service.dart';

/// Live TV's browsable categories, in the order Live TV shows them:
/// first-appearance order (channels arrive in the provider's order), or A–Z.
/// Hidden categories are left out, adult ones too on a kids profile, and
/// anything [skip] matches (e.g. locked categories in the player's panel).
/// A profile's own [order] wins over both: categories it lists come first,
/// in that order; the rest (new ones) follow in the default order.
List<String> liveCategories(
  Iterable<Channel> channels, {
  Set<String> hidden = const {},
  bool isKid = false,
  bool az = false,
  List<String> order = const [],
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
  if (order.isEmpty) return cats;
  final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
  final listed = cats.where(rank.containsKey).toList()
    ..sort((a, b) => rank[a]!.compareTo(rank[b]!));
  return [...listed, ...cats.where((c) => !rank.containsKey(c))];
}
