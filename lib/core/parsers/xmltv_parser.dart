import 'package:open_iptv/core/models/programme.dart';
import 'package:xml/xml_events.dart';

class XmltvParser {
  /// Stream-parses an XMLTV feed and yields Programme objects.
  ///
  /// Never loads the full document into memory — safe for large EPG feeds.
  /// Keeps only programmes within [windowDays] days from now.
  static Stream<Programme> parse(
    Stream<String> chunks, {
    int windowDays = 5,
  }) async* {
    final cutoffEnd = DateTime.now().add(Duration(days: windowDays));
    final cutoffStart = DateTime.now().subtract(const Duration(hours: 1));

    String? currentChannelId;
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

    await for (final event
        in chunks.toXmlEvents().normalizeEvents().flatten()) {
      if (event is XmlStartElementEvent) {
        switch (event.name) {
          case 'channel':
            currentChannelId = event.attributes
                .firstWhere((a) => a.name == 'id',
                    orElse: () => _emptyAttr)
                .value;
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
        if (inTitle) progTitle = (progTitle ?? '') + event.value;
        if (inDesc) progDesc = (progDesc ?? '') + event.value;
        if (inCategory) progCategory = (progCategory ?? '') + event.value;
        if (inEpisodeNum) progEpisodeNum = (progEpisodeNum ?? '') + event.value;
      } else if (event is XmlEndElementEvent) {
        switch (event.name) {
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

    _ = currentChannelId; // suppress unused warning — used for future channel matching
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

  // "+0100" → Duration(hours: 1), "-0530" → Duration(hours: -5, minutes: -30)
  static Duration _parseTzOffset(String tz) {
    if (tz.isEmpty) return Duration.zero;
    try {
      final sign = tz.startsWith('-') ? -1 : 1;
      final digits = tz.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 4) return Duration.zero;
      final hours = int.parse(digits.substring(0, 2));
      final minutes = int.parse(digits.substring(2, 4));
      return Duration(hours: sign * hours, minutes: sign * minutes);
    } catch (_) {
      return Duration.zero;
    }
  }

  static final _emptyAttr = _FakeAttr('');
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
  XmlAttributeType get attributeType => XmlAttributeType.DOUBLE_QUOTE;
}
