import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/parsers/xmltv_parser.dart';
import 'package:open_iptv/core/services/epg_service.dart' show maybeGunzip;

/// Opens a guide (XMLTV) address as a stream of XML text. Plain XML, `.gz`
/// and `.zip` files all work as long as they unpack to XML; the type is
/// recognised from the file's first bytes, not its name.
///
/// [tempDir] is where a zip is unpacked (zips cannot be read as a stream).
/// Call [GuideSource.close] when done.
Future<GuideSource> openGuide(String url,
    {required String tempDir, bool latin1 = false}) async {
  // [latin1]: hand out the raw bytes one character each, for callers that
  // only scan for ASCII markers (see XmltvParser `latin1Input`).
  final Converter<List<int>, String> decoder = latin1
      ? const Latin1Decoder(allowInvalid: true)
      : const Utf8Decoder(allowMalformed: true);
  final client = http.Client();
  final tempFiles = <FileSystemEntity>[];
  Future<void> close() async {
    client.close();
    for (final f in tempFiles) {
      try {
        await f.delete(recursive: true);
      } catch (_) {}
    }
  }

  try {
    final streamed = await client
        .send(http.Request('GET', Uri.parse(url)))
        .timeout(const Duration(seconds: 90));
    if (streamed.statusCode != 200) {
      throw http.ClientException('http_${streamed.statusCode}');
    }

    // Look at the first bytes to tell zip from gzip from plain XML.
    final it = StreamIterator(streamed.stream);
    final head = <int>[];
    final first = <List<int>>[];
    while (head.length < 4 && await it.moveNext()) {
      first.add(it.current);
      head.addAll(it.current);
    }
    Stream<List<int>> all() async* {
      yield* Stream.fromIterable(first);
      while (await it.moveNext()) {
        yield it.current;
      }
    }

    final isZip = head.length >= 4 &&
        head[0] == 0x50 &&
        head[1] == 0x4b &&
        head[2] == 0x03 &&
        head[3] == 0x04;
    if (!isZip) {
      return GuideSource(
          maybeGunzip(all()).transform(decoder),
          close);
    }

    // A zip: save it, unpack it, read the biggest .xml inside.
    final dir = await Directory(tempDir).createTemp('guide_');
    tempFiles.add(dir);
    final zipFile = File('${dir.path}/guide.zip');
    final sink = zipFile.openWrite();
    await sink.addStream(all());
    await sink.close();
    final out = Directory('${dir.path}/out')..createSync();
    await extractFileToDisk(zipFile.path, out.path);
    await zipFile.delete();
    File? best;
    for (final e in out.listSync(recursive: true)) {
      if (e is File && e.path.toLowerCase().endsWith('.xml')) {
        if (best == null || e.lengthSync() > best.lengthSync()) best = e;
      }
    }
    if (best == null) throw http.ClientException('zip_without_xml');
    return GuideSource(
        maybeGunzip(best.openRead()).transform(decoder),
        close);
  } catch (_) {
    await close();
    rethrow;
  }
}

class GuideSource {
  GuideSource(this.text, this.close);
  final Stream<String> text;
  final Future<void> Function() close;
}

/// The channels a guide lists. Runs off the main isolate.
Future<List<({String id, String name})>> fetchGuideChannels(
    String url, String tempDir) {
  return Isolate.run(() async {
    final src = await openGuide(url, tempDir: tempDir);
    try {
      final out = <({String id, String name})>[];
      await for (final c in XmltvParser.parseChannels(src.text)
          .timeout(const Duration(seconds: 120))) {
        out.add(c);
      }
      if (out.isEmpty) throw http.ClientException('empty_guide');
      return out;
    } finally {
      await src.close();
    }
  });
}

/// The programmes of [channelIds] (XMLTV ids) in a guide, in the window the
/// app keeps. Runs off the main isolate; programmes of other channels are
/// dropped while parsing, so a huge guide costs time but not memory.
Future<List<Programme>> fetchGuideProgrammes(
  String url,
  String tempDir,
  Set<String> channelIds, {
  required Duration pastWindow,
  required int daysAhead,
  required bool keepDescriptions,
}) {
  return Isolate.run(() async {
    final src = await openGuide(url, tempDir: tempDir, latin1: true);
    try {
      final out = <Programme>[];
      await for (final p in XmltvParser.parse(
        src.text,
        pastWindow: pastWindow,
        windowDays: daysAhead,
        keepDescriptions: keepDescriptions,
        onlyChannels: channelIds,
        latin1Input: true,
      )) {
        out.add(p);
      }
      return out;
    } finally {
      await src.close();
    }
  });
}
