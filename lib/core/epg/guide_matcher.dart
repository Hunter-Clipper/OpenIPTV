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

/// What to call a guide channel that has no `display-name` (some feeds only
/// have ids like "BBC.One.HD.uk"): the id with its dots read as spaces.
String nameFromGuideId(String id) =>
    id.replaceAll(RegExp(r'[._]+'), ' ').trim();

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
  const NormalisedName(this.tokens, this.region);

  final Set<String> tokens;

  /// 'uk', 'us', ... or null when the name does not say.
  final String? region;

  String get squashed => (tokens.toList()..sort()).join();
  bool get isEmpty => tokens.isEmpty;
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
    r'^[\s|\[(]*(uk|gb|usa|us|ca|can|au|aus|ie|nz)[\s|\])]*(?:[:\-|]|\s-\s)\s*',
    caseSensitive: false);
final _bracketed = RegExp(r'[\(\[|]\s*([^\)\]|]*?)\s*[\)\]|]');
final _timeShift = RegExp(r'\+\s*(\d{1,2})\b');

/// Words, region and time shift of a channel name, ignoring decoration like
/// "HD", "(USA)" or "UK - ".
NormalisedName normaliseChannelName(String raw) {
  var s = raw.toLowerCase().replaceAll('&', ' and ');
  String? region;

  // "UK - BBC One", "|UK| BBC One", "US: HBO".
  final prefix = _regionPrefix.firstMatch(s);
  if (prefix != null) {
    region = _regionWords[prefix.group(1)];
    s = s.substring(prefix.end);
  }

  // "(UK)", "[US]", "|CA|" anywhere. Only region words are taken out of the
  // brackets; other bracketed text ("(Geo-blocked)") is simply dropped.
  s = s.replaceAllMapped(_bracketed, (m) {
    final inner = m.group(1)!.trim();
    final r = _regionWords[inner];
    if (r != null) region ??= r;
    return ' ';
  });

  // "+1" style time shifts become a word of their own.
  s = s.replaceAllMapped(_timeShift, (m) => ' plus${m.group(1)} ');
  // "AMC+" is AMC Plus, not AMC.
  s = s.replaceAll('+', ' plus ');

  var tokens = s
      .split(RegExp(r'[^a-z0-9À-ɏ]+'))
      .where((t) => t.isNotEmpty)
      .map((t) => _numberWords[t] ?? t)
      .toList();

  // "BBC One UK": a region as the last of several words.
  // Feeds also end ids with a number ("us2", "uk1").
  final lastRegion = tokens.isEmpty
      ? null
      : _regionWords[tokens.last.replaceFirst(RegExp(r'\d$'), '')];
  if (tokens.length >= 2 && lastRegion != null) {
    region ??= lastRegion;
    tokens = tokens.sublist(0, tokens.length - 1);
  }

  tokens = tokens.where((t) => !_qualityWords.contains(t)).toList();
  // "ITV1" and "ITV 1" are the same name.
  tokens = [
    for (final t in tokens)
      if (RegExp(r'^[a-z]+\d+$').hasMatch(t) && !t.startsWith('plus'))
        ...RegExp(r'[a-z]+|\d+').allMatches(t).map((m) => m[0]!)
      else
        t,
  ];
  final strong = tokens.where((t) => !_weakWords.contains(t)).toList();
  if (strong.any((t) => !RegExp(r'^\d+$').hasMatch(t))) tokens = strong;

  return NormalisedName(tokens.toSet(), region);
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
  final numA = a.tokens.where((t) => RegExp(r'\d').hasMatch(t)).toSet();
  final numB = b.tokens.where((t) => RegExp(r'\d').hasMatch(t)).toSet();
  if (numA.length != numB.length || !numA.containsAll(numB)) return 0;

  double score;
  if (a.squashed == b.squashed) {
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

/// Finds the guide channel for a playlist channel.
class GuideMatcher {
  GuideMatcher(Iterable<GuideChannel> channels, {this.threshold = 0.85}) {
    final list = channels.toList();
    _locals = LocalStationIndex(list);
    for (final c in list) {
      // The id often says the region ("...uk") when the display name does not.
      final idRegion = normaliseChannelName(nameFromGuideId(c.xmltvId)).region;
      final variants = [
        for (final v in _nameVariants(c.name).map(normaliseChannelName))
          NormalisedName(v.tokens, v.region ?? idRegion),
      ];
      final index = _entries.length;
      _entries.add(_Entry(c, variants));
      _byId.putIfAbsent(c.xmltvId.toLowerCase(), () => c);
      for (final v in variants) {
        for (final t in v.tokens) {
          (_postings[t] ??= <int>{}).add(index);
        }
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

    final queries = <NormalisedName>[
      for (final n in [name, if (tvgName != null) tvgName])
        // "BBC 3 / CBBC (UK)": either half may be the guide's name.
        for (final part in n.split(RegExp(r'\s+/\s+|\s*\|\s*(?=\S+\s*\|)')))
          normaliseChannelName(part),
      normaliseChannelName(name),
    ].where((q) => !q.isEmpty).toList();

    final scores = <int, double>{};
    for (final q in queries) {
      final candidates = <int>{};
      for (final t in q.tokens) {
        final posting = _postings[t];
        if (posting == null || posting.length > _commonLimit) continue;
        candidates.addAll(posting);
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

  /// Guide channels whose name contains every word of [query], for the
  /// manual picker. Best matches first.
  List<GuideChannel> search(String query, {int limit = 50}) {
    final q =
        query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    if (q.isEmpty) return const [];
    final hits = <(double, GuideChannel)>[];
    final qn = normaliseChannelName(query);
    for (final e in _entries) {
      final name = e.channel.name.toLowerCase();
      if (!q.every(name.contains)) continue;
      var s = 0.0;
      for (final v in e.variants) {
        final x = scoreNames(qn, v);
        if (x > s) s = x;
      }
      hits.add((s, e.channel));
    }
    hits.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final h in hits.take(limit)) h.$2];
  }
}

class _Entry {
  _Entry(this.channel, this.variants);
  final GuideChannel channel;
  final List<NormalisedName> variants;
}
