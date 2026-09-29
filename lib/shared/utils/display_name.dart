import 'package:flutter/widgets.dart';

/// Tidies a provider-supplied channel, category or title name for display:
///
///  - drops leading provider tags — `|EN| `, `| DOC | `, `US| `, `4K| `,
///    `A+ - `, `EN - ` (repeatedly: `|VOD| EN - …`), and the language tag
///    in numbered titles (`01 EN - X` → `01 X`);
///  - drops superscript decorations (`ᴿᴬᵂ ⁶⁰ᶠᵖˢ`, `ᴴᴰ`);
///  - turns ALL-CAPS names into Title Case, keeping real acronyms (ESPN, HBO,
///    UHD, NFL…) and resolutions ("3840p");
///  - spaces out word/word pairs ("HORROR/THRILLER" → "Horror / Thriller").
///
/// Mixed-case names ("DrewLive Adult Swim 24/7") only get the tag and
/// decoration stripping. Display only — search, sorting, parental locks and
/// genre icons all keep using the raw name. If cleaning would leave nothing,
/// the original is returned.
String cleanDisplayName(String raw) {
  var s = raw.replaceAll(_decorations, ' ').replaceAll(_padding, ' ');
  String before;
  do {
    before = s;
    s = s.replaceFirst(_leadingTag, '');
    // "01 EN - Friday The 13th" → "01 Friday The 13th": keep the provider's
    // franchise number, drop the language tag after it.
    s = s.replaceFirstMapped(_numberedTag, (m) => '${m[1]} ');
  } while (s != before);
  s = s
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\s\-|:/·•]+|[\s\-|:/·•]+$'), '')
      .trim();
  if (s.isEmpty) return raw.trim();
  if (_isAllCaps(s)) s = _titleCase(s);
  return s.replaceAllMapped(
      RegExp(r'([A-Za-z]{3,})\s*/\s*([A-Za-z]{3,})'), (m) => '${m[1]} / ${m[2]}');
}

// Runs of filler characters providers pad names with ("###### Relax ######",
// "=== SPORTS ===", "★★").
final _padding = RegExp(r'[#*=~_★☆●•◆■▶►]{2,}');

// Unicode superscript / modifier-letter blocks used as decorations.
final _decorations = RegExp(r'[ʰ-˿ᴀ-ᶿ⁰-₟]+');

// "|EN|", "| DOC |", "|VOD |"  ·  "US|", "4K|", "18|"  ·  "A+ - ", "EN - "
final _leadingTag = RegExp(
    r'^\s*(?:\|\s*[^|]{1,12}?\s*\||[A-Z0-9+]{1,5}\s*\||[A-Z0-9+]{1,4}\s+-\s+)\s*');

// "01 EN - ", "12 FR - " (two letters only: "90 DAY - …" is a title)
final _numberedTag = RegExp(r'^\s*(\d{1,3})\s+[A-Z]{2}\s+-\s+');

bool _isAllCaps(String s) {
  final upper = RegExp('[A-Z]').allMatches(s).length;
  return upper >= 3 && !RegExp('[a-z]').hasMatch(s);
}

String _titleCase(String s) {
  var first = true;
  return s.split(' ').map((word) {
    final out = _titleWord(word, first);
    if (RegExp('[A-Za-z0-9]').hasMatch(word)) first = false;
    return out;
  }).join(' ');
}

String _titleWord(String word, bool first, {bool part = false}) {
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
      DisplayNames.enabledOf(this) ? cleanDisplayName(raw) : raw;
}
