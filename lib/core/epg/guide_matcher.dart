/// Matching a channel's name to the channels of a guide (XMLTV) file, for
/// smart guide assignment (#40). Pure Dart: no database, no network.
library;

import 'local_stations.dart';

/// One channel listed at the top of an XMLTV file.
class GuideChannel {
  const GuideChannel({
    required this.guideId,
    required this.xmltvId,
    required this.name,
  });

  /// The extra guide this channel belongs to.
  final String guideId;

  /// The `id` the file's programmes use in their `channel` attribute.
  final String xmltvId;

  /// The first `display-name`, as the file writes it ("UK - BBC One").
  final String name;
}

// Compiled once: matching runs over tens of thousands of channels.
final _reDot = RegExp(r'[._]+');
final _reIdRegion = RegExp(r'^([a-z]{2,3})(?:\d+|_[a-z0-9_]+)?$');
final _reSplit = RegExp(r'[^a-z0-9À-ɏ]+');
final _reTrailDigit = RegExp(r'\d$');
final _reLetterDigit = RegExp(r'^[a-z]+\d+$');
final _reParts = RegExp(r'[a-z]+|\d+');
final _reAllDigits = RegExp(r'^\d+$');
final _reThe = RegExp(r'^the');
final _reTail = RegExp(r'(tv|channel|network)$');
final _reHasDigit = RegExp(r'\d');
final _reNameParts = RegExp(r'\s+/\s+|\s*\|\s*(?=\S+\s*\|)');
final _reSpace = RegExp(r'\s+');

/// What to call a guide channel that has no `display-name` (some feeds only
/// have ids like "BBC.One.HD.uk"): the id with its dots read as spaces.
String nameFromGuideId(String id) {
  var base = id;
  // "BBC.One.HD.uk", "WNBC-DT.us_locals1": the region is said separately.
  final dot = id.lastIndexOf('.');
  if (dot > 0 && regionOfGuideId(id) != null) base = id.substring(0, dot);
  return base.replaceAll(_reDot, ' ').trim();
}

/// A guide channel judged to be the same station as a playlist channel.
class GuideMatch {
  const GuideMatch(this.channel, this.score, {this.byId = false});

  final GuideChannel channel;

  /// 0 to 1; 1 is an exact match.
  final double score;

  /// Matched on the guide id the playlist already carried, not on the name.
  final bool byId;
}

/// A name broken into what matters for comparing it: words and a region.
class NormalisedName {
  NormalisedName(this.tokens, this.region,
      [this.ordered = const [],
      this.orderedStem = const [],
      this.keys = const {}]);

  /// The words with plurals folded ("sport" = "sports").
  final Set<String> tokens;

  /// 'uk', 'us', ... or null when the name does not say.
  final String? region;

  /// The words in the order written: "FOX Soccer Plus" and "FOXSoccerPlus"
  /// both read `foxsoccerplus`. [orderedStem] is the same with plurals
  /// folded, so "TNT Sport 2" and "TNTSports2" meet too.
  final List<String> ordered;
  final List<String> orderedStem;

  /// Other spellings of the same name, all joined without spaces: with the
  /// decorations left in ("ABC News Live" = "ABCNewsLive") and without a
  /// leading "the" or trailing "tv" / "channel" ("MAV TV" = "MAVTV"). Two
  /// names sharing one are the same name.
  final Set<String> keys;

  /// Words holding a digit: BBC 1 and BBC 2 differ here.
  late final Set<String> numbers = {
    for (final t in tokens)
      if (_reHasDigit.hasMatch(t)) t,
  };

  String get squashed => ordered.join();
  String get squashedStem => orderedStem.join();
  bool get isEmpty => tokens.isEmpty;

  NormalisedName withRegion(String? r) =>
      NormalisedName(tokens, r, ordered, orderedStem, keys);
}

const _regionWords = {
  'uk': 'uk',
  'gb': 'uk',
  'us': 'us',
  'usa': 'us',
  'ca': 'ca',
  'can': 'ca',
  'au': 'au',
  'aus': 'au',
  'ie': 'ie',
  'nz': 'nz',
};

// Country codes providers and guides use. Only taken as a region where it is
// clearly a region: a "DE|" prefix, "(DE)" brackets or an id's last segment
// ("SkySportNews.de"), never a bare word at the end of a name.
const _countryCodes = {
  'ae', 'al', 'ar', 'at', 'au', 'ba', 'be', 'bg', 'br', 'ca', 'ch', 'cl',
  'cn', 'co', 'cz', 'de', 'dk', 'ee', 'eg', 'es', 'fi', 'fr', 'gr', 'hk',
  'hr', 'hu', 'id', 'ie', 'il', 'in', 'ir', 'is', 'it', 'jp', 'kr', 'lt',
  'lv', 'ma', 'mk', 'mt', 'mx', 'my', 'ng', 'nl', 'no', 'nz', 'pe', 'ph',
  'pk', 'pl', 'pt', 'qa', 'ro', 'rs', 'ru', 'sa', 'se', 'sg', 'si', 'sk',
  'th', 'tn', 'tr', 'tw', 'ua', 'uy', 've', 'vn', 'za', 'la', 'lat', 'ex',
};

/// 'uk' for "gb" / "UK" and so on; null if [code] is not a country code.
String? regionOfCode(String code) {
  final c = code.toLowerCase();
  return _regionWords[c] ?? (_countryCodes.contains(c) ? c : null);
}

/// The region a guide id ends with: `BBCOne.uk`, `ESPN.HD.us2`,
/// `WNBC-DT.us_locals1` -> 'uk' / 'us' / 'us'. Null when it does not say.
String? regionOfGuideId(String id) {
  final dot = id.lastIndexOf('.');
  if (dot < 0) return null;
  final last = id.substring(dot + 1).toLowerCase();
  final m = _reIdRegion.firstMatch(last);
  return m == null ? null : regionOfCode(m.group(1)!);
}

const _resolutionWords = {
  'hd', 'fhd', 'uhd', 'sd', 'hq', 'lq', '4k', '8k', 'hevc', 'h265', 'h264',
  'raw', '1080p', '1080i', '720p', '50fps', '60fps', 'fps', 'hdr',
};

const _qualityWords = {
  'hd',
  'fhd',
  'uhd',
  'sd',
  'hq',
  'lq',
  '4k',
  '8k',
  'hevc',
  'h265',
  'h264',
  'raw',
  '1080p',
  '1080i',
  '720p',
  '50fps',
  '60fps',
  'fps',
  'vip',
  'backup',
  'hdr',
  'multi',
  'live',
};

// Words that only decorate a name. Dropped when something else is left.
const _weakWords = {'channel', 'network', 'tv', 'the'};

const _numberWords = {
  'one': '1',
  'two': '2',
  'three': '3',
  'four': '4',
  'five': '5',
  'six': '6',
  'seven': '7',
  'eight': '8',
  'nine': '9',
  'ten': '10',
};

final _regionPrefix = RegExp(
    r'^[\s|\[(]*([a-z]{2,3})[\s|\])]*(?:[:\-|]|\s-\s)\s*',
    caseSensitive: false);
// "PRIME| ", "4K| ", "TV| ": a one-word provider tag before a bar.
final _tagPrefix = RegExp(r'^\s*[a-z0-9+]{1,8}\s*\|\s*(?=\S)');
final _bracketed = RegExp(r'[\(\[|]\s*([^\)\]|]*?)\s*[\)\]|]');
final _timeShift = RegExp(r'\+\s*(\d{1,2})\b');

/// Words, region and time shift of a channel name, ignoring decoration like
/// "HD", "(USA)" or "UK - ".
NormalisedName normaliseChannelName(String raw) {
  var s = raw.toLowerCase().replaceAll('&', ' and ');
  String? region;

  // "UK - BBC One", "|UK| BBC One", "US: HBO", "DE| Sky": a region prefix
  // (and, after it or on its own, one-word provider tags like "4K|").
  for (var i = 0; i < 3; i++) {
    final prefix = _regionPrefix.firstMatch(s);
    final r = prefix == null ? null : regionOfCode(prefix.group(1)!);
    if (prefix != null && r != null) {
      region ??= r;
      s = s.substring(prefix.end);
      continue;
    }
    final tag = _tagPrefix.firstMatch(s);
    if (tag == null) break;
    s = s.substring(tag.end);
  }

  // "(UK)", "[US]", "|CA|" anywhere. Only region words are taken out of the
  // brackets; other bracketed text ("(Geo-blocked)") is simply dropped.
  s = s.replaceAllMapped(_bracketed, (m) {
    final inner = m.group(1)!.trim();
    final r = regionOfCode(inner);
    if (r != null) region ??= r;
    return ' ';
  });

  // "+1" style time shifts become a word of their own.
  s = s.replaceAllMapped(_timeShift, (m) => ' plus${m.group(1)} ');
  // "AMC+" is AMC Plus, not AMC.
  s = s.replaceAll('+', ' plus ');

  var tokens = s
      .split(_reSplit)
      .where((t) => t.isNotEmpty)
      .map((t) => _numberWords[t] ?? t)
      .toList();

  // "BBC One UK": a region as the last of several words.
  // Feeds also end ids with a number ("us2", "uk1").
  final lastRegion = tokens.isEmpty
      ? null
      : _regionWords[tokens.last.replaceFirst(_reTrailDigit, '')];
  if (tokens.length >= 2 && lastRegion != null) {
    region ??= lastRegion;
    tokens = tokens.sublist(0, tokens.length - 1);
  }

  // Everything but resolution tags: "ABC News Live" keeps its "live".
  final full = [
    for (final t in tokens)
      if (!_resolutionWords.contains(t)) t,
  ];
  tokens = tokens.where((t) => !_qualityWords.contains(t)).toList();
  // "ITV1" and "ITV 1" are the same name.
  tokens = [
    for (final t in tokens)
      if (_reLetterDigit.hasMatch(t) && !t.startsWith('plus'))
        ..._reParts.allMatches(t).map((m) => m[0]!)
      else
        t,
  ];
  final strong = tokens.where((t) => !_weakWords.contains(t)).toList();
  if (strong.any((t) => !_reAllDigits.hasMatch(t))) tokens = strong;

  // Plurals fold together ("sport" / "sports", "kid" / "kids").
  String stem(String t) => t.length > 3 &&
          t.endsWith('s') &&
          !t.endsWith('ss') &&
          !t.endsWith('us') &&
          !t.endsWith('is')
      ? t.substring(0, t.length - 1)
      : t;

  final stemmed = tokens.map(stem).toList();
  final keys = <String>{};
  void addKeys(String joined) {
    if (joined.length < 4) return;
    keys.add(joined);
    final core = joined
        .replaceFirst(_reThe, '')
        .replaceFirst(_reTail, '');
    if (core.length >= 3) keys.add(core);
  }

  addKeys(tokens.join());
  addKeys(stemmed.join());
  addKeys(full.join());
  addKeys(full.map(stem).join());

  return NormalisedName(stemmed.toSet(), region, tokens, stemmed, keys);
}

/// A guide's names often read "<category> - <name>": "UK - MysteryX",
/// "NCAAF - Eastern Illinois Panthers". The name part alone is also tried.
List<String> _nameVariants(String raw) {
  final variants = <String>[raw];
  final dash = raw.indexOf(' - ');
  if (dash > 0 && dash < raw.length - 3) {
    variants.add(raw.substring(dash + 3));
  }
  return variants;
}

/// Compares two normalised names: 0 (different), up to 1 (the same).
double scoreNames(NormalisedName a, NormalisedName b) {
  if (a.isEmpty || b.isEmpty) return 0;
  // BBC 1 and BBC 2, or a +1 channel and its parent, are never the same.
  final numA = a.numbers;
  final numB = b.numbers;
  if (numA.length != numB.length || !numA.containsAll(numB)) return 0;

  double score;
  if (a.squashed == b.squashed ||
      a.squashedStem == b.squashedStem ||
      a.keys.any(b.keys.contains)) {
    score = 1;
  } else {
    final common = a.tokens.intersection(b.tokens).length;
    score = 2 * common / (a.tokens.length + b.tokens.length);
  }
  if (a.region != null && b.region != null) {
    score = a.region == b.region ? score + 0.03 : score * 0.5;
  }
  return score > 1 ? 1 : score;
}

String _setKey(NormalisedName n) => (n.tokens.toList()..sort()).join(' ');

/// Finds the guide channel for a playlist channel.
class GuideMatcher {
  GuideMatcher(Iterable<GuideChannel> channels, {this.threshold = 0.99}) {
    final list = channels.toList();
    _locals = LocalStationIndex(list);
    for (final c in list) {
      // The id often says the region ("...uk") when the display name does not.
      final idRegion = regionOfGuideId(c.xmltvId);
      final variants = [
        for (final v in _nameVariants(c.name).map(normaliseChannelName))
          v.withRegion(v.region ?? idRegion),
      ];
      final index = _entries.length;
      _entries.add(_Entry(c, variants));
      _byId.putIfAbsent(c.xmltvId.toLowerCase(), () => c);
      for (final v in variants) {
        for (final t in v.tokens) {
          (_postings[t] ??= <int>{}).add(index);
        }
        if (v.squashed.isNotEmpty) {
          (_bySquashed[v.squashed] ??= <int>{}).add(index);
          (_bySquashed[v.squashedStem] ??= <int>{}).add(index);
        }
        for (final k in v.keys) {
          (_bySquashed[k] ??= <int>{}).add(index);
        }
        (_bySet[_setKey(v)] ??= <int>{}).add(index);
      }
    }
  }

  /// Lowest score accepted as a match.
  final double threshold;

  /// How much better the best match must be than the runner-up for the
  /// match to be trusted.
  static const margin = 0.04;

  // Tokens in more guide channels than this carry no information ("tv").
  static const _commonLimit = 400;

  final _entries = <_Entry>[];
  final _byId = <String, GuideChannel>{};
  final _postings = <String, Set<int>>{};
  // Entries by their words joined: "SkySportNews" is found from "SKY SPORT NEWS".
  final _bySquashed = <String, Set<int>>{};
  // Entries by their sorted word set: "Sky Sport News" = "News Sky Sport".
  final _bySet = <String, Set<int>>{};
  late final LocalStationIndex _locals;

  int get length => _entries.length;

  /// The guide channel whose id equals [tvgId], if the guide has one.
  GuideMatch? matchById(String? tvgId) {
    if (tvgId == null || tvgId.isEmpty) return null;
    final c = _byId[tvgId.toLowerCase()];
    return c == null ? null : GuideMatch(c, 1, byId: true);
  }

  /// The best guide channel for a playlist channel, or null when nothing is
  /// good enough or two guide channels fit equally well.
  GuideMatch? match(String name, {String? tvgId, String? tvgName}) {
    // Playlists repeat names (the same channel in two playlists): answer once.
    final key = '$name\u0000${tvgId ?? ''}\u0000${tvgName ?? ''}';
    if (_memo.containsKey(key)) return _memo[key];
    return _memo[key] = _match(name, tvgId, tvgName);
  }

  final _memo = <String, GuideMatch?>{};

  GuideMatch? _match(String name, String? tvgId, String? tvgName) {
    final byId = matchById(tvgId);
    if (byId != null) return byId;

    // Local stations are keyed by call sign. A name that looks local but
    // cannot be resolved safely gets no guide at all rather than the
    // national guide of the same network.
    for (final n in [name, if (tvgName != null) tvgName]) {
      final local = _locals.resolve(n);
      if (local.kind == LocalKind.resolved) {
        return GuideMatch(local.channel!, local.byCallSign ? 0.98 : 0.9);
      }
      if (local.kind == LocalKind.unresolved) return null;
    }

    // "BBC 3 / CBBC (UK)": either half may be the guide's name. Each distinct
    // spelling is normalised once.
    final spellings = <String>{
      for (final n in [name, if (tvgName != null) tvgName])
        ...n.split(_reNameParts),
      name,
    };
    final queries = [
      for (final t in spellings) normaliseChannelName(t),
    ].where((q) => !q.isEmpty).toList();

    final scores = <int, double>{};
    // Exact names only (the default) need no scanning of near neighbours:
    // look the name up under every spelling it has.
    final exactOnly = threshold >= 0.99;
    for (final q in queries) {
      final candidates = <int>{};
      if (exactOnly) {
        candidates
          ..addAll(_bySet[_setKey(q)] ?? const <int>{})
          ..addAll(_bySquashed[q.squashed] ?? const <int>{})
          ..addAll(_bySquashed[q.squashedStem] ?? const <int>{});
        for (final k in q.keys) {
          candidates.addAll(_bySquashed[k] ?? const <int>{});
        }
      } else {
        for (final t in q.tokens) {
          final posting = _postings[t];
          if (posting == null || posting.length > _commonLimit) continue;
          candidates.addAll(posting);
        }
        candidates
          ..addAll(_bySquashed[q.squashed] ?? const <int>{})
          ..addAll(_bySquashed[q.squashedStem] ?? const <int>{});
        for (final k in q.keys) {
          candidates.addAll(_bySquashed[k] ?? const <int>{});
        }
      }
      for (final i in candidates) {
        var best = 0.0;
        for (final v in _entries[i].variants) {
          final s = scoreNames(q, v);
          if (s > best) best = s;
        }
        if (best > (scores[i] ?? 0)) scores[i] = best;
      }
    }

    int? bestIndex;
    int? secondIndex;
    var best = 0.0;
    var second = 0.0;
    for (final e in scores.entries) {
      if (e.value > best) {
        second = best;
        secondIndex = bestIndex;
        best = e.value;
        bestIndex = e.key;
      } else if (e.value > second) {
        second = e.value;
        secondIndex = e.key;
      }
    }
    if (bestIndex == null || best < threshold) return null;
    // Two guide channels that fit equally well. In different guides it is the
    // same station listed twice: the guide given first wins. In one guide
    // (two "BBC One" regions) a pick would be as likely wrong as right.
    if (secondIndex != null && best - second < margin) {
      final a = _entries[bestIndex].channel;
      final b = _entries[secondIndex].channel;
      if (a.guideId == b.guideId) {
        if (a.xmltvId != b.xmltvId) {
          // "FX HD" and "FX HD (Pacific)": the plain one is the main feed.
          if (a.name.length == b.name.length) return null;
          if (b.name.length < a.name.length) bestIndex = secondIndex;
        }
      } else if (secondIndex < bestIndex) {
        bestIndex = secondIndex;
      }
    }
    return GuideMatch(_entries[bestIndex].channel, best);
  }

  /// Likely guide channels for a playlist channel, best first, including
  /// guesses too weak to link automatically: the manual picker shows them for
  /// a person to choose from.
  List<GuideChannel> suggest(String name, {int limit = 8}) {
    final out = <GuideChannel>[];
    final local = _locals.resolve(name);
    if (local.kind == LocalKind.resolved) out.add(local.channel!);
    final q = normaliseChannelName(name);
    if (!q.isEmpty) {
      final scored = <(double, int)>[];
      for (var i = 0; i < _entries.length; i++) {
        var best = 0.0;
        for (final v in _entries[i].variants) {
          var s = scoreNames(q, v);
          // One name inside the other ("Spectrum News 1" in "Spectrum News 1
          // Dallas"): a likely relative, worth showing.
          final a = q.squashed, b = v.squashed;
          if (s < 0.7 &&
              a.length >= 5 &&
              b.length >= 5 &&
              (a.contains(b) || b.contains(a)) &&
              (q.region == null || v.region == null || q.region == v.region)) {
            s = 0.7;
          }
          if (s > best) best = s;
        }
        if (best >= 0.4) scored.add((best, i));
      }
      scored.sort((a, b) {
        final c = b.$1.compareTo(a.$1);
        return c != 0 ? c : a.$2.compareTo(b.$2);
      });
      for (final (_, i) in scored) {
        final c = _entries[i].channel;
        if (!out.any((o) => o.guideId == c.guideId && o.xmltvId == c.xmltvId)) {
          out.add(c);
        }
        if (out.length >= limit) break;
      }
    }
    return out.take(limit).toList();
  }

  /// Guide channels whose name contains every word of [query], for the
  /// manual picker. Best matches first.
  ///
  /// [like] is the playlist channel being edited: results from its own region
  /// come first ("UK: BBC 1" shows the UK BBC One before the Dutch one), and
  /// guides listed first win ties.
  List<GuideChannel> search(String query, {int limit = 50, String? like}) {
    final q =
        query.toLowerCase().split(_reSpace).where((t) => t.isNotEmpty);
    if (q.isEmpty) return const [];
    final region = like == null ? null : normaliseChannelName(like).region;
    final hits = <(int, double, int, GuideChannel)>[];
    final qn = normaliseChannelName(query);
    for (var i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      final name = e.channel.name.toLowerCase();
      if (!q.every(name.contains)) continue;
      var s = 0.0;
      String? r;
      for (final v in e.variants) {
        final x = scoreNames(qn, v);
        if (x > s) s = x;
        r ??= v.region;
      }
      // 0: same region, 1: region unknown, 2: a different region.
      final rank = region == null || r == null
          ? 1
          : (r == region ? 0 : 2);
      hits.add((rank, s, i, e.channel));
    }
    hits.sort((a, b) {
      if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
      if (a.$2 != b.$2) return b.$2.compareTo(a.$2);
      return a.$3.compareTo(b.$3);
    });
    return [for (final h in hits.take(limit)) h.$4];
  }
}

class _Entry {
  _Entry(this.channel, this.variants);
  final GuideChannel channel;
  final List<NormalisedName> variants;
}
