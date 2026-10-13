import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/models/source.dart';
import 'package:open_iptv/core/parsers/xmltv_parser.dart';
import 'package:open_iptv/shared/utils/redact.dart';
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
    // A failed download isn't an empty guide — say so (the caller logs it
    // and keeps the programmes already saved).
    if (streamed.statusCode != 200) {
      throw http.ClientException('http_${streamed.statusCode}');
    }
    final bodyStream =
        maybeGunzip(streamed.stream).transform(const Utf8Decoder());
    await for (final prog
        in XmltvParser.parse(bodyStream, pastWindow: pastWindow)) {
      programmes.add(prog);
    }
  } finally {
    client.close();
  }
  return programmes;
}

/// Guides are often served as `.xml.gz` without a `Content-Encoding` header
/// (DrewLive sends `application/gzip`), so the HTTP client hands over the
/// compressed bytes. Sniff the gzip magic number and unpack when present.
@visibleForTesting
Stream<List<int>> maybeGunzip(Stream<List<int>> bytes) async* {
  final chunks = StreamIterator(bytes);
  final head = <int>[];
  final firstChunks = <List<int>>[];
  while (head.length < 2 && await chunks.moveNext()) {
    firstChunks.add(chunks.current);
    head.addAll(chunks.current.take(2 - head.length));
  }
  Stream<List<int>> rest() async* {
    yield* Stream.fromIterable(firstChunks);
    while (await chunks.moveNext()) {
      yield chunks.current;
    }
  }

  if (head.length == 2 && head[0] == 0x1f && head[1] == 0x8b) {
    yield* rest().transform(gzip.decoder);
  } else {
    yield* rest();
  }
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

  Future<List<Programme>> getProgrammesForChannelInRange(
    String channelId,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) =>
      db.getProgrammesForChannelInRange(channelId, rangeStart, rangeEnd);

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

    debugPrint(
        '[EPG] Starting fetch for "${source.nickname}": ${redactUrl(epgUrl)}');
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

      // Stored straight under the app's own channel ids, so a refresh
      // updates the rows already there. (It used to store every programme
      // under its XMLTV id and then rewrite them all — twice the writing,
      // 11 minutes on a TV stick — and kept programmes for channels the
      // playlist doesn't have.)
      final ids = await db.channelIdsByTvgId(source.id);
      final mapped = [
        for (final p in programmes)
          if (ids[p.channelId] case final id?)
            Programme(
              channelId: id,
              start: p.start,
              end: p.end,
              title: p.title,
              description: p.description,
              category: p.category,
              episodeNum: p.episodeNum,
            ),
      ];

      var totalWritten = 0;
      for (var i = 0; i < mapped.length; i += 1000) {
        final batch = mapped.sublist(i, (i + 1000).clamp(0, mapped.length));
        await db.upsertProgrammes(batch);
        totalWritten += batch.length;
        onProgress?.call('Loading TV guide… ($totalWritten programs)');
      }

      debugPrint('[EPG] Wrote $totalWritten programmes '
          '(${programmes.length - mapped.length} for channels not in any '
          'playlist skipped) in ${sw.elapsedMilliseconds}ms');
      await db.compact();

      sw.stop();
      debugPrint(
          '[EPG] Done — $totalWritten total in ${sw.elapsedMilliseconds}ms');
    } catch (e, st) {
      sw.stop();
      debugPrint('[EPG] Error after ${sw.elapsedMilliseconds}ms: '
          '${redactUrl('$e')}\n$st');
      // Callers report it ("TV guide isn't available"); swallowing it here
      // made every failed guide refresh look like a success.
      rethrow;
    }
  }

}
