import 'dart:convert';
import 'dart:developer' as dev;

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

  Future<List<Programme>> searchCurrentProgrammes(String query) =>
      db.searchCurrentProgrammes(query);

  /// Fetches and stores EPG data for a source.
  ///
  /// Streams the HTTP response body through the XML parser so the full feed
  /// is never held in memory. DB writes are flushed every 1 000 rows so peak
  /// memory stays flat even for large XMLTV feeds.
  Future<void> refreshEpg(
    Source source, {
    void Function(String)? onProgress,
  }) async {
    final epgUrl = source.epgUrl;
    if (epgUrl == null || epgUrl.isEmpty) {
      dev.log('[EPG] No EPG URL configured for source "${source.nickname}" — skipping.',
          name: 'EpgService');
      return;
    }

    dev.log('[EPG] Starting fetch for "${source.nickname}": $epgUrl',
        name: 'EpgService');
    final sw = Stopwatch()..start();

    try {
      await db.deleteOldProgrammes();

      final uri = Uri.parse(epgUrl);
      final client = http.Client();
      try {
        final request = http.Request('GET', uri);
        final streamed = await client
            .send(request)
            .timeout(const Duration(seconds: 60));

        dev.log('[EPG] Connected in ${sw.elapsedMilliseconds}ms — HTTP ${streamed.statusCode}',
            name: 'EpgService');

        if (streamed.statusCode != 200) {
          dev.log('[EPG] Aborting — unexpected status ${streamed.statusCode}',
              name: 'EpgService');
          return;
        }

        final bodyStream = streamed.stream.transform(utf8.decoder);

        var totalWritten = 0;
        var batchCount = 0;
        final buffer = <Programme>[];

        await for (final prog in XmltvParser.parse(bodyStream)) {
          buffer.add(prog);
          if (buffer.length >= 1000) {
            await db.upsertProgrammes(List.of(buffer));
            totalWritten += buffer.length;
            batchCount++;
            dev.log('[EPG] Batch $batchCount — $totalWritten programmes written (${sw.elapsedMilliseconds}ms)',
                name: 'EpgService');
            onProgress?.call('Loading TV guide… ($totalWritten programs)');
            buffer.clear();
          }
        }
        if (buffer.isNotEmpty) {
          await db.upsertProgrammes(buffer);
          totalWritten += buffer.length;
        }

        onProgress?.call('Mapping guide to channels…');
        await db.remapProgrammeChannelIds();

        sw.stop();
        dev.log('[EPG] Done — $totalWritten total programmes in ${sw.elapsedMilliseconds}ms (remap complete)',
            name: 'EpgService');
      } finally {
        client.close();
      }
    } catch (e, st) {
      sw.stop();
      dev.log('[EPG] Error after ${sw.elapsedMilliseconds}ms: $e',
          name: 'EpgService', error: e, stackTrace: st);
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
