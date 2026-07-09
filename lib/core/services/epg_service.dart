import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/parsers/xmltv_parser.dart';
import 'package:open_iptv/core/services/profile_service.dart';
import 'package:open_iptv/core/storage/database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'epg_service.g.dart';

// Top-level so Isolate.run can reference it.
// Fetches + stream-parses the XMLTV feed entirely off the main thread,
// returning all programmes at once for batch DB writes on the caller.
Future<List<Programme>> _fetchAndParseAll(
  String epgUrl,
  Duration pastWindow,
) async {
  final client = http.Client();
  final programmes = <Programme>[];
  try {
    final request = http.Request('GET', Uri.parse(epgUrl));
    final streamed =
        await client.send(request).timeout(const Duration(seconds: 90));
    if (streamed.statusCode != 200) return programmes;
    final bodyStream = streamed.stream.transform(utf8.decoder);
    await for (final prog
        in XmltvParser.parse(bodyStream, pastWindow: pastWindow)) {
      programmes.add(prog);
    }
  } finally {
    client.close();
  }
  return programmes;
}

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
  /// HTTP fetch and XMLTV parse run in a temporary background isolate via
  /// Isolate.run so the main thread stays free. The completed list of
  /// programmes is returned to the main isolate for batched DB writes (which
  /// themselves go through the Drift background isolate, keeping I/O off the
  /// main thread too).
  Future<void> refreshEpg(
    Source source, {
    void Function(String)? onProgress,
  }) async {
    final epgUrl = source.epgUrl;
    if (epgUrl == null || epgUrl.isEmpty) {
      debugPrint(
          '[EPG] No EPG URL for "${source.nickname}" — skipping.');
      return;
    }

    debugPrint('[EPG] Starting fetch for "${source.nickname}": $epgUrl');
    final sw = Stopwatch()..start();

    try {
      await db.deleteOldProgrammes();

      final maxCatchupDays = await db.getMaxCatchupDaysForSource(source.id);
      final pastWindow = maxCatchupDays > 0
          ? Duration(days: maxCatchupDays)
          : const Duration(hours: 1);

      onProgress?.call('Downloading TV guide…');
      final programmes = await Isolate.run(
        () => _fetchAndParseAll(epgUrl, pastWindow),
        debugName: 'epg-parse',
      );

      debugPrint(
          '[EPG] Parsed ${programmes.length} programmes in ${sw.elapsedMilliseconds}ms');

      var totalWritten = 0;
      for (var i = 0; i < programmes.length; i += 1000) {
        final batch =
            programmes.sublist(i, (i + 1000).clamp(0, programmes.length));
        await db.upsertProgrammes(batch);
        totalWritten += batch.length;
        onProgress?.call('Loading TV guide… ($totalWritten programs)');
      }

      debugPrint(
          '[EPG] Wrote $totalWritten programmes in ${sw.elapsedMilliseconds}ms');

      if (totalWritten > 0) {
        onProgress?.call('Mapping guide to channels…');
        await db.remapProgrammeChannelIds();
      }

      sw.stop();
      debugPrint(
          '[EPG] Done — $totalWritten total in ${sw.elapsedMilliseconds}ms (remap complete)');
    } catch (e, st) {
      sw.stop();
      debugPrint('[EPG] Error after ${sw.elapsedMilliseconds}ms: $e\n$st');
    }
  }

}
