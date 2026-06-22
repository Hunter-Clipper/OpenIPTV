import 'package:http/http.dart' as http;
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/parsers/xmltv_parser.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'epg_service.g.dart';

@Riverpod(keepAlive: true)
EpgService epgService(EpgServiceRef ref) {
  return EpgService(db: ref.watch(appDatabaseProvider));
}

class EpgService {
  const EpgService({required this.db});

  final AppDatabase db;

  Future<Programme?> getCurrentProgramme(String channelId) =>
      db.getCurrentProgramme(channelId);

  Future<Programme?> getNextProgramme(String channelId) =>
      db.getNextProgramme(channelId);

  Future<List<Programme>> getProgrammesForChannel(
    String channelId,
    DateTime date,
  ) =>
      db.getProgrammesForChannelOnDate(channelId, date);

  Future<List<Programme>> searchProgrammes(String query) =>
      db.searchProgrammes(query);

  /// Fetches and stores EPG data for a source.
  /// Runs from a background context — never call on the main isolate with await
  /// in a UI build; schedule via a background service or WorkManager.
  Future<void> refreshEpg(Source source) async {
    final epgUrl = source.epgUrl;
    if (epgUrl == null || epgUrl.isEmpty) return;

    try {
      await db.deleteOldProgrammes();

      final uri = Uri.parse(epgUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return;

      // Stream-parse via XmltvParser.
      final chunk = Stream.value(response.body);
      final programmes = await XmltvParser.parse(chunk).toList();

      if (programmes.isNotEmpty) {
        await db.upsertProgrammes(programmes);
      }
    } catch (_) {
      // EPG errors are non-fatal — channels still work without guide data.
    }
  }

  /// Matches XMLTV channel IDs to app Channel IDs using the priority:
  /// 1. Exact tvg-id match
  /// 2. Exact tvg-name match (case-insensitive)
  /// 3. Fuzzy name match
  ///
  /// Remap is performed in-DB: channelId stored in Programmes rows already
  /// uses the XMLTV channel attribute. Post-fetch, this method rewrites
  /// channelId values to match the app's internal Channel IDs.
  Future<void> applyEpgOverrides(Map<String, String> overrides) async {
    // overrides: {channelId → tvgId}
    // Applied when profile has custom epgOverrides.
    // Implementation: update programmes where channelId matches old tvgId.
    // Deferred to Phase 1 completion — EPG matching works without this for
    // providers where tvg-id aligns with Xtream stream ID.
  }
}
