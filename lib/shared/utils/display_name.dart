import 'package:flutter/widgets.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';

/// The standard clean-up for any provider's channel, category or title name.
/// Display only — search, sorting, parental locks and genre icons all keep
/// using the raw name. If cleaning would leave nothing, the original is
/// returned.
///
/// One pipeline for every naming style:
///  1. **Normalise** — drop decorations (`ᴿᴬᵂ`, `✶⋆✶`, `#####`), fix `_` and
///     back-ticks.
///  2. **Tidy live events** — slot prefix (`US (ESPN+ 024): `), `ENDED |` /
///     `NO EVENT STREAMING` state, a repeated team line, `|`-separated parts.
///  3. **Peel markers** from the front (`|EN|`, `US|`, `USA: `, `EN - `,
///     `01 EN - `, `[1080p]`), anywhere in brackets (`(1080p)`, `[4K-Q]`,
///     `[24/7 O-D]`, `(Sweden)`) and from the end (` HD`, ` UHD/4K`).
///     Each marker is classified from the dictionaries below:
///       quality (HD, 1080p, 576i, H265, RAW…) → dropped;
///       4K / UHD → a short `4K` at the end;
///       country / language → `(Region)` at the end, English is dropped;
///       `24/7` and `Events` stay in place, `[Not 24/7]` / `[EXTRA]` go,
///       `[Geo-blocked]` is kept;
///       event state → `- Ended` / `- Next` / `- Not started` at the end.
///     Short codes in a `|` or ` - ` prefix are always provider tags and are
///     peeled even when unknown; everything else must be a known marker, so
///     real titles (`Mission: Impossible`, `NFL Teams: …`, `(2022)`, `(Home)`)
///     are never touched.
///  4. **Re-case** ALL-CAPS names to Title Case (keeping acronyms and
///     resolutions) and space out `word/word`. Mixed-case names keep their
///     capitals.
///  5. **Assemble**: `Name` + `4K` + `(Region)` + `[Geo-blocked]` + `- State`.
String cleanDisplayName(String raw, {AppLocalizations? l10n}) {
  final c = _Found();
  var s = raw
      .replaceAll(_decorations, ' ')
      .replaceAll(_padding, ' ')
      .replaceAll('`', "'")
      .replaceAll(RegExp(r'\s_\s'), ' - ');
  s = _tidyEvent(s, c);
  if (c.slotOnly != null) return c.slotOnly!;
  s = _peel(s, c);
  s = s
      .replaceAll(RegExp(r'\(\s*\)'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s\-|:/·•]+|[\s\-|:/·•]+$'), '')
      .trim();
  if (s.isEmpty) return raw.trim();
  if (_isAllCaps(s)) s = _titleCase(s);
  s = s
      .replaceAllMapped(RegExp(r'([A-Za-z]{3,})\s*/\s*([A-Za-z]{3,})'),
          (m) => '${m[1]} / ${m[2]}')
      .replaceAll(_p247, '24/7')
      .replaceAll(_pEvents, 'Events')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (c.fourK) s = '$s 4K';
  if (c.region != null) s = '$s (${c.region})';
  if (c.geo) s = '$s [${l10n?.formatGeoBlocked ?? 'Geo-blocked'}]';
  if (c.state != null) s = '$s - ${_stateLabel(c.state!, l10n)}';
  return s;
}

/// The event state (kept as English text while parsing, so already-cleaned
/// names still match) in the app language.
String _stateLabel(String state, AppLocalizations? l10n) {
  if (l10n == null) return state;
  return switch (state) {
    'Ended' => l10n.formatStateEnded,
    'Next' => l10n.formatStateNext,
    'Live' => l10n.formatStateLive,
    'Not started' => l10n.formatStateNotStarted,
    _ => state,
  };
}

/// What the markers of one name told us.
class _Found {
  String? region;
  bool fourK = false;
  bool geo = false;
  bool isEvent = false;
  String? state;
  String? slotOnly;

  void addRegion(String label) {
    if (label.isNotEmpty) region ??= label;
  }
}

// Stand-ins for "24/7" and "Events", swapped in after re-casing.
const _p247 = '';
const _pEvents = '';

// ---------------------------------------------------------------------------
// Marker dictionaries
// ---------------------------------------------------------------------------

/// Codes that may lead a name (`US|`, `USA: `, `FR - `): code → what to show
/// at the end ('' = just drop).
const _prefixRegions = <String, String>{
  'US': 'USA', 'USA': 'USA', 'UK': 'UK', 'GB': 'UK', 'CA': 'CAN',
  'CAN': 'CAN', 'AU': 'AU', 'NZ': 'NZ', 'IE': 'IE', 'NA': 'NA', 'EU': 'EU',
  'GLOBAL': 'Global', 'MULTI': 'Multi', 'EN': '', 'TV': '',
  'PRIME': 'Prime', 'TUBI': 'Tubi',
  'FR': 'FR', 'DE': 'DE', 'ES': 'ES', 'IT': 'IT', 'PT': 'PT', 'PL': 'PL',
  'NL': 'NL', 'SE': 'SE', 'NO': 'NO', 'DK': 'DK', 'FI': 'FI', 'TR': 'TR',
  'RU': 'RU', 'AR': 'AR', 'ARA': 'ARA', 'GR': 'GR', 'RO': 'RO', 'HU': 'HU',
  'CZ': 'CZ', 'BG': 'BG', 'RS': 'RS', 'HR': 'HR', 'UA': 'UA', 'IN': 'IN',
  'PK': 'PK', 'BR': 'BR', 'MX': 'MX', 'KR': 'KR', 'JP': 'JP', 'CN': 'CN',
};

/// Codes recognised inside brackets, `(US)`, `[FR]`. Fewer than above: `(CA)`,
/// `(DE)`, `(PA)`… are as often US states in sports names.
const _bracketRegions = <String, String>{
  'US': 'USA', 'USA': 'USA', 'UK': 'UK', 'GB': 'UK', 'AU': 'AU', 'NZ': 'NZ',
  'FR': 'FR', 'ES': 'ES', 'IT': 'IT', 'PT': 'PT', 'PL': 'PL', 'NL': 'NL',
  'TR': 'TR', 'RU': 'RU', 'KR': 'KR', 'JP': 'JP', 'MX': 'MX', 'BR': 'BR',
};

/// Country names in brackets, `(Sweden)`, `(United Kingdom)`.
const _countries = {
  'AFGHANISTAN', 'ALBANIA', 'ALGERIA', 'ANDORRA', 'ANGOLA', 'ARGENTINA',
  'ARMENIA', 'AUSTRALIA', 'AUSTRIA', 'AZERBAIJAN', 'BAHRAIN', 'BANGLADESH',
  'BELARUS', 'BELGIUM', 'BOLIVIA', 'BOSNIA AND HERZEGOVINA', 'BRAZIL',
  'BULGARIA', 'CAMBODIA', 'CAMEROON', 'CANADA', 'CHILE', 'CHINA', 'COLOMBIA',
  'COSTA RICA', 'CROATIA', 'CUBA', 'CYPRUS', 'CZECH REPUBLIC', 'CZECHIA',
  'DENMARK', 'DOMINICAN REPUBLIC', 'ECUADOR', 'EGYPT', 'EL SALVADOR',
  'ESTONIA', 'ETHIOPIA', 'FINLAND', 'FRANCE', 'GEORGIA', 'GERMANY', 'GHANA',
  'GREECE', 'GUATEMALA', 'HAITI', 'HONDURAS', 'HONG KONG', 'HUNGARY',
  'ICELAND', 'INDIA', 'INDONESIA', 'IRAN', 'IRAQ', 'IRELAND', 'ISRAEL',
  'ITALY', 'JAMAICA', 'JAPAN', 'JORDAN', 'KAZAKHSTAN', 'KENYA', 'KOSOVO',
  'KUWAIT', 'KYRGYZSTAN', 'LATVIA', 'LEBANON', 'LIBYA', 'LITHUANIA',
  'LUXEMBOURG', 'MACAU', 'MALAYSIA', 'MALTA', 'MEXICO', 'MOLDOVA', 'MONGOLIA',
  'MONTENEGRO', 'MOROCCO', 'MYANMAR', 'NEPAL', 'NETHERLANDS', 'NEW ZEALAND',
  'NICARAGUA', 'NIGERIA', 'NORTH MACEDONIA', 'NORWAY', 'OMAN', 'PAKISTAN',
  'PALESTINE', 'PANAMA', 'PARAGUAY', 'PERU', 'PHILIPPINES', 'POLAND',
  'PORTUGAL', 'PUERTO RICO', 'QATAR', 'ROMANIA', 'RUSSIA', 'SAUDI ARABIA',
  'SENEGAL', 'SERBIA', 'SINGAPORE', 'SLOVAKIA', 'SLOVENIA', 'SOMALIA',
  'SOUTH AFRICA', 'SOUTH KOREA', 'SPAIN', 'SRI LANKA', 'SUDAN', 'SWEDEN',
  'SWITZERLAND', 'SYRIA', 'TAIWAN', 'TAJIKISTAN', 'TANZANIA', 'THAILAND',
  'TUNISIA', 'TURKEY', 'TURKIYE', 'TURKMENISTAN', 'UGANDA', 'UKRAINE',
  'UNITED ARAB EMIRATES', 'UNITED KINGDOM', 'UNITED STATES',
  'UNITED STATES OF AMERICA', 'URUGUAY', 'UZBEKISTAN', 'VENEZUELA', 'VIETNAM',
  'YEMEN', 'ZIMBABWE',
};

// Quality / technical markers that are simply dropped.
final _qualityMarker = RegExp(
    r'^(\d{3,4}[PI]|HD|FHD|SD|QHD|H\.?26[45]|HEVC|AVC|RAW|\d{2}\s?FPS|LQ|HQ|'
    r'8K EXCLUSIVE|NOT 24/7|EXTRA)$');
final _fourKMarker = RegExp(r'^(4K(-Q)?|UHD(/4K)?|4K UHD|2160P)$');
final _alwaysOn = RegExp(r'^24[/-]7(\s*O-?D)?$');

// ---------------------------------------------------------------------------
// Pipeline steps
// ---------------------------------------------------------------------------

/// Peels markers from the front, from brackets and from the end until the
/// name stops changing.
String _peel(String s, _Found c) {
  String before;
  do {
    before = s;
    s = s.replaceFirst(RegExp(r'^[\s/|:]+'), '');
    s = _peelPrefix(s, c);
    s = s.replaceAllMapped(_bracket, (m) => _bracketMarker(m[1]!, c) ?? m[0]!);
    s = _peelSuffix(s, c);
  } while (s != before);
  return s;
}

// "|EN|", "| DOC |", "|VOD |"
final _pipedPrefix = RegExp(r'^\|\s*([^|]{1,14}?)\s*\|\s*');
// "US|", "4K|", "18|", "PRIME|", "US (…) |" handled as an event slot
final _codePipe = RegExp(r'^([A-Za-z0-9+]{1,6})\s*\|\s*');
// "A+ - ", "EN - ", "NF  - "
final _codeDash = RegExp(r'^\s*([A-Z0-9+]{1,4})\s+-\s+');
// "01 EN - ", "12 FR - " (two letters only: "90 DAY - …" is a title)
final _numberedTag = RegExp(r'^\s*(\d{1,3})\s+[A-Z]{2}\s+-\s+');
// "USA: ", "UK: ", "EN: " — only known codes, a colon alone proves nothing
final _codeColon = RegExp(r'^\s*([A-Z]{1,6})\s*:\s+');
// "…: USA: ESPN+ …" inside an event line
final _regionMid = RegExp(
    r'(?<=[-:]\s)(US|USA|UK|GB|CA|CAN|AU|NZ|IE|NA|EU|GLOBAL|MULTI|PRIME|TUBI)'
    r':\s+');

String _peelPrefix(String s, _Found c) {
  var m = _pipedPrefix.firstMatch(s) ??
      _codePipe.firstMatch(s) ??
      _codeDash.firstMatch(s);
  if (m != null) {
    _prefixMarker(m[1]!, c);
    return s.substring(m.end);
  }
  m = _numberedTag.firstMatch(s);
  if (m != null) return s.replaceFirstMapped(_numberedTag, (m) => '${m[1]} ');
  m = _codeColon.firstMatch(s);
  if (m != null && _prefixRegions.containsKey(m[1])) {
    c.addRegion(_prefixRegions[m[1]]!);
    return s.substring(m.end);
  }
  return s;
}

/// A tag that led the name behind a `|` or ` - `: always peeled, only
/// remembered if it says something we show.
void _prefixMarker(String text, _Found c) {
  final t = text.trim().toUpperCase();
  if (_prefixRegions.containsKey(t)) {
    c.addRegion(_prefixRegions[t]!);
  } else if (_fourKMarker.hasMatch(t)) {
    c.fourK = true;
  }
}

// "[1080p]", "(576i)", "[Not 24/7]", "(Sweden)" — anywhere in the name.
final _bracket = RegExp(r'[\[(]\s*([^\[\]()]{1,24}?)\s*[\])]');

/// What a bracketed marker is replaced with, or null to leave it alone.
String? _bracketMarker(String text, _Found c) {
  if (text.contains(';')) {
    // "[Not 24/7;Geo-blocked]": every part has to be a known marker.
    final parts = text.split(';');
    if (parts.any((p) => _bracketMarker(p, _Found()) == null)) return null;
    for (final p in parts) {
      _bracketMarker(p, c);
    }
    return ' ';
  }
  final t = text.trim().toUpperCase();
  if (_qualityMarker.hasMatch(t)) return ' ';
  if (_fourKMarker.hasMatch(t)) {
    c.fourK = true;
    return ' ';
  }
  if (_alwaysOn.hasMatch(t)) return ' $_p247 ';
  if (t == 'PPV EVENTS') return ' $_pEvents ';
  if (t == 'GEO-BLOCKED') {
    c.geo = true;
    return ' ';
  }
  // An event's time zone, "(US)" after the time, is not the channel's country.
  if (c.isEvent) return null;
  final code = _bracketRegions[t];
  if (code != null) {
    c.addRegion(code);
    return ' ';
  }
  if (_countries.contains(t)) {
    c.addRegion(t == 'UNITED STATES' || t == 'UNITED STATES OF AMERICA'
        ? 'USA'
        : t == 'UNITED KINGDOM'
            ? 'UK'
            : text.trim());
    return ' ';
  }
  return null;
}

// Trailing "HD", "FHD", "HEVC"… and "UHD", "4K", "UHD/4K".
final _trailingQuality =
    RegExp(r'(?:\s+(?:HD|FHD|SD|HEVC|H\.?26[45]))+\s*$');
final _trailingFourK =
    RegExp(r'\s+(?:HDR/)?(?:UHD/4K|4K UHD|UHD|4K)\+?\s*$');
// "Freddy's 2 4K (2025)": a bare 4K right before the year.
final _fourKBeforeYear = RegExp(r'\s+4K(?=\s*\(\d{4}\))');
// "NAME - FR", "NAME | UK": a known code after a separator.
final _suffixCode = RegExp(r'\s+[-|]\s+([A-Z]{2,6})\s*$');
// "AR: DAZN PPV 1 - NO EVENT STREAMING - | 8K EXCLUSIVE": state at the end.
final _stateAtEnd = RegExp(
    r'\s+-\s+(NO EVENT STREAMING(?: NOW)?|THE EVENT HAS NOT BEGUN(?: NOW)?)'
    r'\s*-?\s*(?:\|.*)?$',
    caseSensitive: false);
// "… - Ended" left by an earlier clean-up.
final _suffixState = RegExp(r'\s+-\s+(Ended|Next|Live|Not started)\s*$');

String _peelSuffix(String s, _Found c) {
  s = s.replaceFirst(_trailingQuality, '');
  if (_trailingFourK.hasMatch(s)) {
    c.fourK = true;
    s = s.replaceFirst(_trailingFourK, '');
  }
  if (_fourKBeforeYear.hasMatch(s)) {
    c.fourK = true;
    s = s.replaceFirst(_fourKBeforeYear, '');
  }
  final end = _stateAtEnd.firstMatch(s);
  if (end != null) {
    c.state ??= 'Not started';
    s = s.substring(0, end.start);
  }
  final st = _suffixState.firstMatch(s);
  if (st != null) {
    c.state ??= st[1];
    s = s.substring(0, st.start);
  }
  final m = _suffixCode.firstMatch(s);
  if (m != null && _prefixRegions.containsKey(m[1])) {
    c.addRegion(_prefixRegions[m[1]]!);
    s = s.substring(0, m.start);
  }
  return s;
}

// ---------------------------------------------------------------------------
// Live events
// ---------------------------------------------------------------------------

// Event slots: "US (ESPN+ 024): ", "(FLSP 253) | ".
final _eventSlot = RegExp(
    r'^\s*(?:[A-Z]{2,4}\s*)?\(([^()]{1,30}?\s\d{1,4})\)\s*[:|]\s*');
final _placeholderDate =
    RegExp(r'^\s*\(\d{4}-\d{2}-\d{2}[^)]*\)\s*(\[[^\]]*\]\s*)*$');
// "ENDED | …", "End: …", "NEXT | …", "- NO EVENT STREAMING - | …",
// "THE EVENT HAS NOT BEGUN -:  : …"
final _eventState = RegExp(
    r'^\s*-?\s*(ENDED|END|NEXT|LIVE(?=\s*\|)|NO EVENT STREAMING(?: NOW)?|'
    r'THE EVENT HAS NOT BEGUN(?: NOW)?)\s*-?\s*[|:]\s*:?\s*',
    caseSensitive: false);

String _tidyEvent(String s, _Found c) {
  String? slot;
  s = s.replaceFirstMapped(_eventSlot, (m) {
    slot = m[1]!.trim();
    return '';
  });
  // An empty slot only has its placeholder date left: show the slot's name.
  if (slot != null && (s.trim().isEmpty || _placeholderDate.hasMatch(s))) {
    c.slotOnly = slot;
    return s;
  }
  final st = _eventState.firstMatch(s);
  if (st != null) {
    final t = st[1]!.toUpperCase();
    c.state = t.startsWith('END')
        ? 'Ended'
        : t == 'NEXT'
            ? 'Next'
            : t == 'LIVE'
                ? 'Live'
                : 'Not started';
    s = s.substring(st.end);
  }
  // A time with its zone, "17:00 EST (US)", also marks an event line.
  if (slot != null || c.state != null || _timeThenZone.hasMatch(s)) {
    c.isEvent = true;
    // "A vs B | Sun 01 Nov 10:30 EST (US) | 8K EXCLUSIVE | US: ESPN+ 7"
    if (s.contains('|')) {
      s = s
          .split('|')
          .map((p) => p.trim())
          .where((p) =>
              p.isNotEmpty &&
              p.toLowerCase() != 'all' &&
              !_qualityMarker.hasMatch(p.toUpperCase()))
          .join(' - ');
    }
    s = s.replaceFirstMapped(_regionMid, (m) {
      c.addRegion(_prefixRegions[m[1]]!);
      return '';
    });
  }
  s = _dropRepeatedTeams(s);
  return s
      .replaceAll(RegExp(r':\s*:'), ':')
      .replaceAll(RegExp(r'\s+:\s'), ': ');
}

final _timeThenZone = RegExp(r'\d{1,2}:\d{2}\s*[A-Za-z]{0,4}\s*\(');

/// "Soccer: Racing vs. Real Madrid (Racing vs. Real Madrid) (2026-…)" →
/// the bracketed copy of the line before it is dropped.
String _dropRepeatedTeams(String s) {
  for (final m in RegExp(r'\(([^()]{4,80})\)').allMatches(s)) {
    final inner = m[1]!.trim();
    final head = s.substring(0, m.start).trimRight();
    if (head.endsWith(inner)) {
      return '$head${s.substring(m.end)}';
    }
  }
  return s;
}

// Runs of filler characters providers pad names with ("###### Relax ######",
// "=== SPORTS ===", "★★").
final _padding = RegExp(r'[#*=~_★☆●•◆■▶►✶⋆✷✸✦✧]{2,}');

// Unicode superscript / modifier-letter blocks used as decorations.
final _decorations = RegExp(r'[ʰ-˿ᴀ-ᶿ⁰-₟]+');

bool _isAllCaps(String s) {
  final upper = RegExp('[A-Z]').allMatches(s).length;
  return upper >= 3 && !RegExp('[a-z]').hasMatch(s);
}

String _titleCase(String s) {
  var first = true;
  return s.split(' ').map((word) {
    final out = _titleWord(word, first);
    // "24/7 THE AFFAIR": the number doesn't use up the capital letter, and a
    // word after a colon starts a new phrase.
    if (RegExp('[A-Za-z]').hasMatch(word)) first = word.endsWith(':');
    return out;
  }).join(' ');
}

String _titleWord(String word, bool first, {bool part = false}) {
  // US station call letters in brackets: "(KWYB)", "(WRBL)".
  if (RegExp(r'^\([KW][A-Z]{2,3}\)$').hasMatch(word)) return word;
  // Hyphen- and slash-joined parts are cased separately ("STAND-UP" →
  // "Stand-Up", "HORROR/THRILLER" → "Horror/Thriller").
  for (final sep in const ['-', '/']) {
    if (word.contains(sep) && word.length > 1) {
      var firstPart = first;
      return word.split(sep).map((p) {
        // Only hyphen parts lose the short-code rule ("STAND-UP"); slash
        // parts are separate words ("PRE-RELEASES/SD CAM" keeps "SD").
        final out = _titleWord(p, firstPart, part: sep == '-');
        firstPart = false;
        return out;
      }).join(sep);
    }
  }
  final letters = word.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (letters.isEmpty) return word;
  final key = letters.toUpperCase();
  if (_special.containsKey(key)) {
    return word.replaceFirst(letters, _special[key]!);
  }
  if (_acronyms.contains(key)) return word;
  // Unknown acronyms: no vowels (BTN, KTLA, WGN) — but not Mr, Mrs, St…
  if (!part &&
      RegExp(r'^[A-Z]{2,5}$').hasMatch(word) &&
      !RegExp('[AEIOUY]').hasMatch(word) &&
      !_noVowelWords.contains(word)) {
    return word;
  }
  if (RegExp(r'^\d+P$').hasMatch(key)) return word.toLowerCase(); // 3840P
  if (RegExp(r'\d').hasMatch(key)) return word; // 4K, F1, 24/7, VH1
  // Short standalone words are usually codes; parts of "STAND-UP" aren't.
  if (!part && letters.length <= 2 && !_smallWords.contains(key.toLowerCase())) {
    return word; // US, UK, TV, HD, X
  }
  final lower = word.toLowerCase();
  if (!first && _smallWords.contains(lower.replaceAll(RegExp('[^a-z&]'), ''))) {
    return lower;
  }
  // Capitalise the first letter; keep the rest lower ("KING'S" → "King's").
  final i = lower.indexOf(RegExp('[a-z]'));
  return i < 0
      ? lower
      : lower.substring(0, i) + lower[i].toUpperCase() + lower.substring(i + 1);
}

const _smallWords = {
  'a', 'an', 'and', 'the', 'of', 'for', 'in', 'on', 'at', 'to', 'by', 'or',
  'vs', 'with', 'from', 'de', 'la', 'le', 'el', 'y',
};

const _special = {'IMDB': 'IMDb'};

const _noVowelWords = {'MR', 'MRS', 'MS', 'ST', 'VS', 'SR', 'JR', 'NR'};

const _acronyms = {
  'HBO', 'NBA', 'NFL', 'NHL', 'MLB', 'MLS', 'UFC', 'WWE', 'AEW', 'ESPN',
  'CNN', 'BBC', 'BBCI', 'ITV', 'ITVX', 'ABC', 'CBS', 'NBC', 'PBS', 'AMC',
  'MGM', 'BET', 'UHD', 'FHD', 'HEVC', 'EPL', 'EFL', 'VIP', 'PPV', 'MTV',
  'HGTV', 'TLC', 'TNT', 'TBS', 'USA', 'DAZN', 'NCAA', 'NCAAF', 'NCAAB',
  'WNBA', 'AFL', 'NRL', 'GAA', 'PGA', 'LPGA', 'ATP', 'WTA', 'IPL', 'UEFA',
  'FIFA', 'NHK', 'TSN', 'BTN', 'SEC', 'ACC', 'MSNBC', 'CNBC', 'CSPAN', 'QVC',
  'HSN', 'FXX', 'AXS', 'IFC', 'TCM', 'DIY', 'PDC', 'MXGP', 'WRC', 'NHRA',
  'OHL', 'AHL', 'WHL', 'QMJHL', 'KHL', 'LOI', 'NIFL', 'NFHS', 'FITE', 'MILB',
  'DVD', 'XXX', 'VOD', 'UFL', 'XFL', 'CFL', 'MMA', 'EWTN', 'CBN', 'TBN',
  'NASA', 'NASCAR', 'WGN', 'KTLA', 'CTV', 'CBC', 'RTE', 'SBS', 'RAI', 'TVE',
  'ZDF', 'ARD', 'ORF', 'SRF', 'NPO', 'VRT', 'ATV', 'RTL', 'DR', 'NRK', 'SVT',
  'YLE', 'TRT', 'ERT', 'SABC', 'NDTV', 'PTV', 'GMA', 'BRT', 'AAC',
};

/// Whether names are cleaned — set once near the root from the user's
/// setting (Settings → Appearance), read with `context.displayName(...)`.
class DisplayNames extends InheritedWidget {
  const DisplayNames({super.key, required this.enabled, required super.child});

  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DisplayNames>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(DisplayNames oldWidget) =>
      enabled != oldWidget.enabled;
}

extension DisplayNameContext on BuildContext {
  /// [raw] tidied for display, unless the user turned cleaning off.
  String displayName(String raw) =>
      DisplayNames.enabledOf(this)
          ? cleanDisplayName(raw,
              l10n: Localizations.of<AppLocalizations>(this, AppLocalizations))
          : raw;
}
