import 'dart:convert';
import 'package:open_iptv/core/models/programme.dart';
import 'package:xml/xml_events.dart';

class XmltvParser {
  /// Stream-parses an XMLTV feed and yields Programme objects.
  ///
  /// Never loads the full document into memory — safe for large EPG feeds.
  /// Keeps only programmes within [windowDays] days ahead and [pastWindow]
  /// behind now. [pastWindow] should cover the largest catch-up window of
  /// any channel in the source being refreshed — the parser has no
  /// per-channel knowledge, so it's a blunt per-source bound; the caller's
  /// database cleanup pass does the precise per-channel trim afterward.
  static Stream<Programme> parse(
    Stream<String> chunks, {
    int windowDays = 5,
    Duration pastWindow = const Duration(hours: 1),
    bool keepDescriptions = true,
    Set<String>? onlyChannels,
    void Function(String id, String name)? onChannel,
    bool latin1Input = false,
  }) async* {
    // Asked for a few channels out of a big guide: find their blocks by a
    // plain text scan and parse only those (a full XML pass over hundreds
    // of megabytes takes minutes on a TV).
    if (onlyChannels != null) {
      yield* _parseWanted(chunks, onlyChannels,
          windowDays: windowDays,
          pastWindow: pastWindow,
          keepDescriptions: keepDescriptions,
          latin1Input: latin1Input);
      return;
    }
    final cutoffEnd = DateTime.now().add(Duration(days: windowDays));
    final cutoffStart = DateTime.now().subtract(pastWindow);

    DateTime? progStart;
    DateTime? progEnd;
    String? progChannel;
    String? progTitle;
    String? progDesc;
    String? progCategory;
    String? progEpisodeNum;
    bool inTitle = false;
    bool inDesc = false;
    bool inCategory = false;
    bool inEpisodeNum = false;
    // The channel list rides along when someone wants it.
    String? chanId;
    final chanName = StringBuffer();
    var inChName = false;
    var gotChName = false;

    await for (final event
        in chunks.toXmlEvents().normalizeEvents().flatten()) {
      if (event is XmlStartElementEvent) {
        switch (event.name) {
          case 'programme':
            progChannel = event.attributes
                .firstWhere((a) => a.name == 'channel',
                    orElse: () => _emptyAttr)
                .value;
            progStart = _parseXmltvTime(event.attributes
                .firstWhere((a) => a.name == 'start',
                    orElse: () => _emptyAttr)
                .value);
            progEnd = _parseXmltvTime(event.attributes
                .firstWhere((a) => a.name == 'stop',
                    orElse: () => _emptyAttr)
                .value);
            progTitle = null;
            progDesc = null;
            progCategory = null;
            progEpisodeNum = null;
          case 'channel':
            if (onChannel != null) {
              chanId = event.attributes
                  .firstWhere((a) => a.name == 'id', orElse: () => _emptyAttr)
                  .value;
              chanName.clear();
              gotChName = false;
            }
          case 'display-name':
            if (chanId != null && !gotChName) inChName = true;
          case 'title':
            inTitle = true;
          case 'desc':
            inDesc = true;
          case 'category':
            inCategory = true;
          case 'episode-num':
            inEpisodeNum = true;
        }
      } else if (event is XmlTextEvent) {
        if (inChName) chanName.write(event.value);
        if (inTitle) progTitle = (progTitle ?? '') + event.value;
        if (inDesc && keepDescriptions) progDesc = (progDesc ?? '') + event.value;
        if (inCategory) progCategory = (progCategory ?? '') + event.value;
        if (inEpisodeNum) progEpisodeNum = (progEpisodeNum ?? '') + event.value;
      } else if (event is XmlEndElementEvent) {
        switch (event.name) {
          case 'display-name':
            if (inChName) gotChName = true;
            inChName = false;
          case 'channel':
            if (chanId != null && chanId.isNotEmpty) {
              onChannel?.call(chanId, chanName.toString().trim());
            }
            chanId = null;
          case 'title':
            inTitle = false;
          case 'desc':
            inDesc = false;
          case 'category':
            inCategory = false;
          case 'episode-num':
            inEpisodeNum = false;
          case 'programme':
            if (progChannel != null &&
                progStart != null &&
                progEnd != null &&
                progTitle != null &&
                progEnd.isAfter(cutoffStart) &&
                progStart.isBefore(cutoffEnd)) {
              yield Programme(
                channelId: progChannel,
                start: progStart,
                end: progEnd,
                title: progTitle.trim(),
                description: progDesc?.trim(),
                category: progCategory?.trim(),
                episodeNum: progEpisodeNum?.trim(),
              );
            }
            progChannel = null;
            progStart = null;
            progEnd = null;
        }
      }
    }

  }

  /// The `channel` attribute of the `<programme ...>` tag spanning
  /// [from]..[to] in [text], found without building a substring (this runs
  /// for every programme of a guide that can hold millions).
  static String? _channelOf(String text, int from, int to) {
    for (final quote in const ['"', "'"]) {
      final key = ' channel=$quote';
      final at = _indexWithin(text, key, from, to);
      if (at < 0) {
        // Also "\nchannel=" / "\tchannel=" after a line break.
        continue;
      }
      final start = at + key.length;
      final end = text.indexOf(quote, start);
      if (end < 0 || end > to) return null;
      return _unescape(text.substring(start, end));
    }
    return _channelOfSlow(text.substring(from, to));
  }

  /// [key] inside [from]..[to] only (a plain indexOf would read on through
  /// the whole buffer when the tag is written another way).
  static int _indexWithin(String text, String key, int from, int to) {
    final last = to - key.length;
    for (var i = from; i <= last; i++) {
      if (text.startsWith(key, i)) return i;
    }
    return -1;
  }

  // Attributes split over lines, or written with spaces around "=".
  static final _reChannelAttr = RegExp(
      r'\bchannel\s*=\s*(?:"([^"]*)"|' "'" r'([^' "'" r']*)' "'" r')');

  static String? _channelOfSlow(String tag) {
    final m = _reChannelAttr.firstMatch(tag);
    return m == null ? null : _unescape(m.group(1) ?? m.group(2) ?? '');
  }

  static final _reNumeric = RegExp(r'&#(x[0-9a-fA-F]+|[0-9]+);');

  static String _unescape(String v) {
    if (!v.contains('&')) return v;
    final numeric = v.contains('&#')
        ? v.replaceAllMapped(_reNumeric, (m) {
            final g = m.group(1)!;
            final code = g.startsWith('x')
                ? int.tryParse(g.substring(1), radix: 16)
                : int.tryParse(g);
            return code == null || code <= 0 || code > 0x10ffff
                ? m.group(0)!
                : String.fromCharCode(code);
          })
        : v;
    return numeric
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
  }

  /// Pulls the `<programme>` blocks of [wanted] channels out of the text and
  /// parses just those, in batches.
  static Stream<Programme> _parseWanted(
    Stream<String> chunks,
    Set<String> wanted, {
    required int windowDays,
    required Duration pastWindow,
    required bool keepDescriptions,
    bool latin1Input = false,
  }) async* {
    // [latin1Input]: the text is the file's raw bytes, one character each
    // (decoding UTF-8 over hundreds of megabytes costs as much as the scan).
    // Tags and ids are ASCII; only the blocks kept are decoded properly.
    final want = latin1Input
        ? {for (final w in wanted) latin1.decode(utf8.encode(w))}
        : wanted;
    var buf = '';
    final batch = StringBuffer();
    var batchSize = 0;

    Stream<Programme> flush() {
      final xml = '<tv>${batch.toString()}</tv>';
      batch.clear();
      batchSize = 0;
      return parse(Stream.value(xml),
          windowDays: windowDays,
          pastWindow: pastWindow,
          keepDescriptions: keepDescriptions);
    }

    await for (final chunk in chunks) {
      buf = buf.isEmpty ? chunk : buf + chunk;
      var pos = 0;
      while (true) {
        final i = buf.indexOf('<programme', pos);
        if (i < 0) {
          // Keep a little in case "<programme" is split across chunks.
          pos = buf.length > 12 ? buf.length - 12 : 0;
          break;
        }
        final gt = buf.indexOf('>', i);
        if (gt < 0) {
          pos = i;
          break;
        }
        final selfClosing = buf.codeUnitAt(gt - 1) == 0x2f; // "/>"
        final int blockEnd;
        if (selfClosing) {
          blockEnd = gt + 1;
        } else {
          final close = buf.indexOf('</programme>', gt);
          if (close < 0) {
            pos = i;
            break;
          }
          blockEnd = close + 12;
        }
        final id = _channelOf(buf, i, gt);
        if (id != null && want.contains(id)) {
          var block = buf.substring(i, blockEnd);
          if (latin1Input) {
            block = utf8.decode(latin1.encode(block), allowMalformed: true);
          }
          batch.write(block);
          batchSize += block.length;
          if (batchSize > 262144) yield* flush();
        }
        pos = blockEnd;
      }
      buf = buf.substring(pos);
    }
    if (batchSize > 0) yield* flush();
  }

  /// The channels a guide lists (id and first display-name). XMLTV puts them
  /// before the programmes, so reading stops at the first programme, which
  /// keeps even a half-gigabyte guide cheap. A file with no channels up
  /// front is read to the end.
  static Stream<({String id, String name})> parseChannels(
      Stream<String> chunks) async* {
    String? id;
    final name = StringBuffer();
    var inName = false;
    var gotName = false;
    var count = 0;
    await for (final event
        in chunks.toXmlEvents().normalizeEvents().flatten()) {
      if (event is XmlStartElementEvent) {
        switch (event.name) {
          case 'channel':
            id = event.attributes
                .firstWhere((a) => a.name == 'id', orElse: () => _emptyAttr)
                .value;
            name.clear();
            gotName = false;
          case 'display-name':
            if (!gotName) inName = true;
          case 'programme':
            if (count > 0) return;
        }
      } else if (event is XmlTextEvent) {
        if (inName) name.write(event.value);
      } else if (event is XmlEndElementEvent) {
        switch (event.name) {
          case 'display-name':
            if (inName) gotName = true;
            inName = false;
          case 'channel':
            if (id != null && id.isNotEmpty) {
              count++;
              yield (id: id, name: name.toString().trim());
            }
            id = null;
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // XMLTV timestamp parsing
  // ---------------------------------------------------------------------------

  // Format: "20250620213000 +0100" or "20250620213000"
  static DateTime? _parseXmltvTime(String raw) {
    if (raw.isEmpty) return null;
    try {
      final clean = raw.trim();
      final spaceIdx = clean.indexOf(' ');
      final datePart = spaceIdx > 0 ? clean.substring(0, spaceIdx) : clean;
      final tzPart = spaceIdx > 0 ? clean.substring(spaceIdx + 1) : '';

      if (datePart.length < 14) return null;

      final year = int.parse(datePart.substring(0, 4));
      final month = int.parse(datePart.substring(4, 6));
      final day = int.parse(datePart.substring(6, 8));
      final hour = int.parse(datePart.substring(8, 10));
      final minute = int.parse(datePart.substring(10, 12));
      final second = int.parse(datePart.substring(12, 14));

      final tzOffset = _parseTzOffset(tzPart);

      return DateTime.utc(year, month, day, hour, minute, second)
          .subtract(tzOffset);
    } catch (_) {
      return null;
    }
  }

  static final _nonDigit = RegExp(r'[^0-9]');

  // "+0100" → Duration(hours: 1), "-0530" → Duration(hours: -5, minutes: -30)
  static Duration _parseTzOffset(String tz) {
    if (tz.isEmpty) return Duration.zero;
    try {
      final sign = tz.startsWith('-') ? -1 : 1;
      final digits = tz.replaceAll(_nonDigit, '');
      if (digits.length < 4) return Duration.zero;
      final hours = int.parse(digits.substring(0, 2));
      final minutes = int.parse(digits.substring(2, 4));
      return Duration(hours: sign * hours, minutes: sign * minutes);
    } catch (_) {
      return Duration.zero;
    }
  }

  static const _emptyAttr = _FakeAttr('');
}

// Avoids allocating a real XmlEventAttribute for missing attributes.
class _FakeAttr implements XmlEventAttribute {
  const _FakeAttr(this.value);

  @override
  final String value;

  @override
  String get name => '';

  @override
  String get localName => '';

  @override
  String get namespacePrefix => '';

  @override
  String get namespaceUri => '';

  @override
  String get qualifiedName => '';

  @override
  XmlAttributeType get attributeType => XmlAttributeType.DOUBLE_QUOTE;

  @override
  XmlStartElementEvent? get parent => null;

  @override
  XmlStartElementEvent? get parentEvent => null;

  @override
  void attachParent(XmlStartElementEvent? parent) {}
}
