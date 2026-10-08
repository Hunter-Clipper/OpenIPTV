import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/providers/theme_providers.dart';
import 'package:open_iptv/core/services/source_manager.dart';
import 'package:open_iptv/shared/utils/friendly_error.dart';
import 'package:open_iptv/shared/utils/redact.dart';

/// Pull-to-refresh on Live TV, Movies and Series: runs [refresh] for the
/// playlist being browsed, or every playlist under "All playlists". A
/// playlist that fails doesn't stop the others, and the failures are shown
/// in a snackbar instead of being thrown into the refresh indicator.
Future<void> refreshBrowsedPlaylists(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(SourceManager manager, Source source) refresh,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final sources = await ref.read(allSourcesProvider.future);
  final activeId = ref.read(activeSourceIdProvider);
  final manager = ref.read(sourceManagerProvider);
  final failed = <(Source, Object)>[];
  for (final s in sources) {
    if (activeId != null && s.id != activeId) continue;
    try {
      await refresh(manager, s);
    } catch (e) {
      debugPrint('[Source] ${s.nickname}: refresh failed: ${redactUrl('$e')}');
      failed.add((s, e));
    }
  }
  if (failed.isEmpty) return;
  final message = failed.length == 1
      ? "Couldn't refresh ${failed.single.$1.nickname}. "
          '${friendlySourceErrorMessage(failed.single.$2)}'
      : "Couldn't refresh ${failed.map((f) => f.$1.nickname).join(', ')}. "
          'Try again later.';
  messenger?.showSnackBar(SnackBar(content: Text(message)));
}
