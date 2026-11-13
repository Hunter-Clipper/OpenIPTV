import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/core/parsers/xmltv_parser.dart';
import 'package:open_iptv/core/services/epg_service.dart' show maybeGunzip;

/// A guide that is bigger than this (compressed, as sent) is refused.
const _maxDownloadBytes = 400 * 1024 * 1024;

/// ...or bigger than this once unpacked (characters, about one byte each).
const _maxUnpackedChars = 2 * 1024 * 1024 * 1024;

/// A guide download that sends nothing for this long is given up on.
const _stallTimeout = Duration(seconds: 60);

/// Hard limit for reading one guide, however slowly it trickles in.
const _overallLimit = Duration(minutes: 12);

/// Removes unpacked-zip folders an earlier run left behind (it was killed
/// before it could clean up). Only `guide_*` folders older than an hour.
Future<void> cleanGuideTemp(String tempDir) async {
  try {
    final dir = Directory(tempDir);
    if (!await dir.exists()) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 1));
    await for (final e in dir.list(followLinks: false)) {
      final name = e.uri.pathSegments.where((p) => p.isNotEmpty).last;
      if (e is Directory && name.startsWith('guide_')) {
        if ((await e.stat()).modified.isBefore(cutoff)) {
          await e.delete(recursive: true);
        }
      }
    }
  } catch (_) {}
}

/// Opens a guide (XMLTV) address as a stream of XML text. Plain XML, `.gz`
/// and `.zip` files all work as long as they unpack to XML; the type is
/// recognised from the file's first bytes, not its name.
///
/// [tempDir] is where a zip is unpacked (zips cannot be read as a stream).
/// [etag] makes the request conditional: when the server says nothing
/// changed, this throws `ClientException('not_modified')`.
/// Call [GuideSource.close] when done.
Future<GuideSource> openGuide(String url,
    {required String tempDir,
    bool latin1 = false,
    String? etag,
    Duration stall = _stallTimeout}) async {
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

  // Counts what the server sends and refuses an absurd amount.
  Stream<List<int>> limited(Stream<List<int>> raw) async* {
    var n = 0;
    await for (final c in raw) {
      n += c.length;
      if (n > _maxDownloadBytes) throw http.ClientException('too_big');
      yield c;
    }
  }

  Stream<String> text(Stream<List<int>> bytes) async* {
    var n = 0;
    await for (final c in maybeGunzip(bytes).transform(decoder)) {
      n += c.length;
      if (n > _maxUnpackedChars) throw http.ClientException('too_big');
      yield c;
    }
  }

  try {
    final request = http.Request('GET', Uri.parse(url));
    if (etag != null && etag.isNotEmpty) request.headers['If-None-Match'] = etag;
    final streamed = await client.send(request).timeout(const Duration(seconds: 90));
    if (streamed.statusCode == 304) throw http.ClientException('not_modified');
    if (streamed.statusCode != 200) {
      throw http.ClientException('http_${streamed.statusCode}');
    }
    final newEtag = streamed.headers['etag'];

    // Look at the first bytes to tell zip from gzip from plain XML. A server
    // that stops sending mid-file ends the read with a timeout.
    final it = StreamIterator(limited(streamed.stream.timeout(stall)));
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
    if (!isZip) return GuideSource(text(all()), close, newEtag);

    // A zip: save it, then stream the biggest .xml inside out to a file (the
    // whole entry is never held in memory) and read that.
    final dir = await Directory(tempDir).createTemp('guide_');
    tempFiles.add(dir);
    final zipFile = File('${dir.path}/guide.zip');
    final sink = zipFile.openWrite();
    await sink.addStream(all());
    await sink.close();
    final xmlFile = File('${dir.path}/guide.xml');
    final input = InputFileStream(zipFile.path);
    try {
      final archive = ZipDecoder().decodeStream(input, throwOnError: true);
      ArchiveFile? best;
      for (final f in archive.files) {
        if (f.isFile && f.name.toLowerCase().endsWith('.xml')) {
          if (best == null || f.size > best.size) best = f;
        }
      }
      if (best == null) throw http.ClientException('zip_without_xml');
      if (best.size > _maxUnpackedChars) throw http.ClientException('too_big');
      final output = OutputFileStream(xmlFile.path);
      try {
        best.writeContent(output);
      } finally {
        await output.close();
      }
    } finally {
      await input.close();
    }
    await zipFile.delete();
    return GuideSource(text(xmlFile.openRead()), close, newEtag);
  } catch (_) {
    await close();
    rethrow;
  }
}

class GuideSource {
  GuideSource(this.text, this.close, [this.etag]);
  final Stream<String> text;
  final Future<void> Function() close;

  /// The server's validator for this version of the file, if it sent one.
  final String? etag;
}

/// The channels a guide lists. Runs off the main isolate.
Future<List<({String id, String name})>> fetchGuideChannels(
    String url, String tempDir,
    {Duration stall = _stallTimeout}) {
  return Isolate.run(() async {
    final src = await openGuide(url, tempDir: tempDir, stall: stall);
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
/// app keeps, in batches as they are found (so a big guide never sits in
/// memory twice). Runs in its own isolate, with a stall timeout and an overall
/// limit. When [etag] is given and the server says the file has not changed,
/// nothing is yielded and [onDone] gets `notModified: true`.
Stream<List<Programme>> streamGuideProgrammes(
  String url,
  String tempDir,
  Set<String> channelIds, {
  required Duration pastWindow,
  required int daysAhead,
  required bool keepDescriptions,
  String? etag,
  Duration stall = _stallTimeout,
  void Function(String? etag, bool notModified)? onDone,
}) async* {
  final rx = ReceivePort();
  Isolate? isolate;
  Timer? cap;
  var finished = false;
  try {
    isolate = await Isolate.spawn(
      _programmesMain,
      [
        rx.sendPort,
        url,
        tempDir,
        channelIds.toList(),
        pastWindow.inMilliseconds,
        daysAhead,
        keepDescriptions,
        etag,
        stall.inMilliseconds,
      ],
      onExit: rx.sendPort,
      onError: rx.sendPort,
    );
    final spawned = isolate;
    cap = Timer(_overallLimit, () {
      spawned.kill(priority: Isolate.immediate);
      rx.sendPort.send(const ['e', 'The guide took too long to download.']);
    });
    await for (final m in rx) {
      if (m == null) {
        if (!finished) throw http.ClientException('isolate_ended');
        break;
      }
      final msg = m as List;
      switch (msg[0]) {
        case 'b':
          yield (msg[1] as List).cast<Programme>();
        case 'd':
          finished = true;
          onDone?.call(msg[1] as String?, false);
          return;
        case 'n':
          finished = true;
          onDone?.call(null, true);
          return;
        case 'e':
          throw http.ClientException(msg[1] as String);
        default:
          // An uncaught error in the isolate: [error, stack].
          throw http.ClientException('${msg[0]}');
      }
    }
  } finally {
    cap?.cancel();
    isolate?.kill(priority: Isolate.immediate);
    rx.close();
  }
}

Future<void> _programmesMain(List<Object?> a) async {
  final port = a[0] as SendPort;
  try {
    final src = await openGuide(a[1] as String,
        tempDir: a[2] as String,
        latin1: true,
        etag: a[7] as String?,
        stall: Duration(milliseconds: a[8] as int));
    try {
      var batch = <Programme>[];
      await for (final p in XmltvParser.parse(
        src.text,
        pastWindow: Duration(milliseconds: a[4] as int),
        windowDays: a[5] as int,
        keepDescriptions: a[6] as bool,
        onlyChannels: (a[3] as List).cast<String>().toSet(),
        latin1Input: true,
      )) {
        batch.add(p);
        if (batch.length >= 2000) {
          port.send(['b', batch]);
          batch = <Programme>[];
        }
      }
      if (batch.isNotEmpty) port.send(['b', batch]);
      port.send(['d', src.etag]);
    } finally {
      await src.close();
    }
  } on http.ClientException catch (e) {
    port.send([e.message == 'not_modified' ? 'n' : 'e', e.message]);
  } catch (e) {
    port.send(['e', '$e']);
  }
}

/// All the programmes of [channelIds] at once (small guides and tests).
Future<List<Programme>> fetchGuideProgrammes(
  String url,
  String tempDir,
  Set<String> channelIds, {
  required Duration pastWindow,
  required int daysAhead,
  required bool keepDescriptions,
}) async {
  final out = <Programme>[];
  await for (final b in streamGuideProgrammes(url, tempDir, channelIds,
      pastWindow: pastWindow,
      daysAhead: daysAhead,
      keepDescriptions: keepDescriptions)) {
    out.addAll(b);
  }
  return out;
}
