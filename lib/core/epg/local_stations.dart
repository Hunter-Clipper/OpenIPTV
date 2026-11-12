/// Local TV stations (US affiliates) for smart guide assignment (#40).
///
/// Guides of local stations are keyed by call sign (`WNBC-DT`, `KMEX-DT`),
/// while playlists name them by network and city ("NBC 4 NEW YORK"), by call
/// sign ("ABC (WPVI) PHILADELPHIA HD") or both. A wrong local guide is worse
/// than none (same network, wrong city's news and schedule), so this only
/// resolves when it is sure, and says "unresolved" otherwise so the caller
/// does not fall back to a national guide of the same network.
library;

import 'guide_matcher.dart';

enum LocalKind {
  /// Not a local station; use ordinary name matching.
  notLocal,

  /// Looks like a local station but no safe match: link nothing.
  unresolved,

  /// A guide channel was found.
  resolved,
}

class LocalResult {
  const LocalResult(this.kind, [this.channel, this.byCallSign = false]);

  static const notLocal = LocalResult(LocalKind.notLocal);
  static const unresolved = LocalResult(LocalKind.unresolved);

  final LocalKind kind;
  final GuideChannel? channel;

  /// True when the name carried the call sign (most reliable); false when
  /// the station was found from network and city.
  final bool byCallSign;
}

/// `WNBC`, `KMEX-DT`, `WNBC-DT2`: letters K or W first, three to four letters.
final _callSignToken = RegExp(
    r'^([kw][a-z]{2,3})(?:-?(tv|dt|hd|cd|ld|lp|ca|d))?(\d)?$',
    caseSensitive: false);

/// What a guide channel id says about its station.
class _Station {
  _Station(this.channel, this.base, this.suffix, this.sub);
  final GuideChannel channel;
  final String base;
  final String suffix;
  final String sub;
}

_Station? _stationOf(GuideChannel c) {
  // "WNBC-DT.us_locals1", "WNBC.us", or "Name.(WNBC-DT).City,.ST.us_locals1".
  final fromId = RegExp(r'^([KW][A-Z]{2,3})(?:-([A-Z]{1,2}))?(\d)?(?:\.|$)')
          .firstMatch(c.xmltvId.toUpperCase()) ??
      RegExp(r'\(([KW][A-Z]{2,3})(?:-([A-Z]{1,2}))?(\d)?\)')
          .firstMatch(c.xmltvId.toUpperCase());
  if (fromId == null) return null;
  return _Station(
      c, fromId.group(1)!, fromId.group(2) ?? '', fromId.group(3) ?? '');
}

// Words after a network name that make it a cable channel, not a local one.
const _cousinWords = {
  'news',
  'sports',
  'sport',
  'business',
  'family',
  'weather',
  'now',
  'universo',
  'golf',
  'soul',
  'movies',
  'classics',
  'kids',
  'drama',
  'nation',
  'deportes',
  'life',
  'entertainment',
  'plus',
  'cinema',
};

// Words that make a call-sign-like token a different channel.
const _notLocalWords = {'america', 'superstation'};

const _networks = {
  'abc': 'abc',
  'cbs': 'cbs',
  'nbc': 'nbc',
  'fox': 'fox',
  'pbs': 'pbs',
  'cw': 'cw',
  'telemundo': 'telemundo',
  'univision': 'univision',
  'mynetworktv': 'mynet',
  'mntv': 'mynet',
};

// Reverse of the market table: station → its network.
final _networkOfSign = <String, String>{
  for (final market in kMarketStations.values)
    for (final e in market.entries) e.value: e.key,
};

// Every word that appears in a market name.
final _marketWords = <String>{
  for (final alias in kMarketAliases.keys) ...alias.split(' '),
};

// Real call signs that are also everyday words or names.
const _wordLikeSigns = {
  'king', 'kyle', 'kids', 'kidz', 'kiss', 'kind', 'kite', 'wish', 'will',
  'wild', 'wave', 'wire', 'wind', 'wall', 'week', 'work', 'word', 'wing',
  'wise', 'wine', 'well', 'wast', 'kcal', 'koin', 'kiwi', 'wood', 'wcw',
};

// Words that decorate a local channel's name without changing which
// station it is.
const _allowedWords = {
  'hd', 'fhd', 'uhd', 'sd', '4k', 'tv', 'dt', 'us', 'usa', 'live', 'and',
  'al', 'ak', 'az', 'ar', 'ca', 'co', 'ct', 'de', 'fl', 'ga', 'hi', 'id',
  'il', 'in', 'ia', 'ks', 'ky', 'la', 'me', 'md', 'ma', 'mi', 'mn', 'ms',
  'mo', 'mt', 'ne', 'nv', 'nh', 'nj', 'nm', 'ny', 'nc', 'nd', 'oh', 'ok',
  'or', 'pa', 'ri', 'sc', 'tn', 'tx', 'ut', 'vt', 'va', 'wa', 'wv',
  'wi', 'wy', 'dc',
};

/// Resolves local stations against a set of guide channels.
class LocalStationIndex {
  LocalStationIndex(Iterable<GuideChannel> channels) {
    for (final c in channels) {
      final s = _stationOf(c);
      if (s != null) (_byBase[s.base] ??= []).add(s);
    }
  }

  final _byBase = <String, List<_Station>>{};

  bool get isEmpty => _byBase.isEmpty;

  /// The guide channel of [base] (`WNBC`): the main broadcast, never a
  /// sub-channel (`-DT2` carries different programming), and only when that
  /// is unambiguous.
  GuideChannel? _main(String base) {
    final all = _byBase[base];
    if (all == null) return null;
    final mains = all.where((s) => s.sub.isEmpty).toList();
    if (mains.isEmpty) return null;
    if (mains.length == 1) return mains.single.channel;
    // WABC-TV and WABC-DT both listed: the digital one, if there is one.
    final dt = mains.where((s) => s.suffix == 'DT').toList();
    return dt.length == 1 ? dt.single.channel : null;
  }

  LocalResult resolve(String name) {
    // "[Geo-blocked]", "[Not 24/7]" and similar tags say nothing about the
    // station.
    final lower = name
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    final tokens = lower
        .split(RegExp(r'[^a-z0-9\-]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.any(_notLocalWords.contains)) return LocalResult.notLocal;

    // "WKAQ-TV 2.2": a virtual channel other than .1 is a sub-channel with
    // programming of its own, not the station's main schedule.
    final virtual = RegExp(r'\b\d{1,3}\.(\d{1,2})\b').firstMatch(lower);
    final isSubChannel = virtual != null && virtual.group(1) != '1';

    final plain = tokens.map((t) => t.replaceAll('-', '')).toList();
    final nets = <String>{};
    final netIndexes = <int>{};
    for (var i = 0; i < plain.length; i++) {
      final n = _networks[plain[i]];
      if (n == null) continue;
      final next = i + 1 < plain.length ? plain[i + 1] : '';
      final prev = i > 0 ? plain[i - 1] : '';
      if (_cousinWords.contains(next) || _cousinWords.contains(prev)) continue;
      nets.add(n);
      netIndexes.add(i);
    }

    // 1. A call sign in the name, confirmed by the guide having it.
    final signIndexes = <int>{};
    final bases = <String>{};
    for (var i = 0; i < tokens.length; i++) {
      final m = _callSignToken.firstMatch(tokens[i]);
      if (m == null) continue;
      final base = m.group(1)!.toUpperCase();
      if (!_byBase.containsKey(base)) continue;
      bases.add(base);
      signIndexes.add(i);
    }
    if (bases.isNotEmpty) {
      // Anything else in the name ("South Park: Kyle Collection", "WOW Kidz",
      // "True Crime Network WCVB", "WSOC Now") means this is a different
      // channel that merely contains something shaped like a call sign.
      if (_hasUnexplainedWords(plain, {...signIndexes, ...netIndexes})) {
        return LocalResult.notLocal;
      }
      // KING, WISH, WILL: call signs that are also ordinary words need more
      // than the word itself ("King TV" is not Seattle's KING).
      final base0 = bases.first.toLowerCase();
      if (bases.length == 1 &&
          _wordLikeSigns.contains(base0) &&
          nets.isEmpty &&
          _marketOf(plain) == null &&
          !tokens.any((t) => RegExp('^$base0-[a-z]{1,2}\\d?\$').hasMatch(t))) {
        return LocalResult.notLocal;
      }
      if (bases.length > 1 || isSubChannel || nets.length > 1) {
        return LocalResult.unresolved;
      }
      final base = bases.single;
      // "Telemundo KNSD": KNSD is NBC's main station; Telemundo there is a
      // sub-channel. A network word that contradicts the station's own is
      // never linked.
      final known = _networkOfSign[base];
      if (nets.isNotEmpty && known != null && nets.single != known) {
        return LocalResult.unresolved;
      }
      final c = _main(base);
      return c == null
          ? LocalResult.unresolved
          : LocalResult(LocalKind.resolved, c, true);
    }

    // 2. Network + city.
    if (nets.length != 1) return LocalResult.notLocal;
    final market = _marketOf(plain);
    if (market == null) return LocalResult.notLocal; // a national feed
    if (isSubChannel || _hasUnexplainedWords(plain, netIndexes)) {
      return LocalResult.unresolved;
    }
    final sign = kMarketStations[market]?[nets.single];
    if (sign == null) return LocalResult.unresolved;
    final c = _main(sign);
    return c == null
        ? LocalResult.unresolved
        : LocalResult(LocalKind.resolved, c);
  }

  /// True when [plain] holds a word that is not a call sign, network, city,
  /// state, number or quality marker (the indexes in [explained] are the
  /// call-sign and network words).
  bool _hasUnexplainedWords(List<String> plain, Set<int> explained) {
    for (var i = 0; i < plain.length; i++) {
      if (explained.contains(i)) continue;
      final t = plain[i];
      if (RegExp(r'^\d+[pi]?$').hasMatch(t)) continue;
      if (_allowedWords.contains(t) || _marketWords.contains(t)) continue;
      return true;
    }
    return false;
  }

  String? _marketOf(List<String> tokens) {
    final text = ' ${tokens.join(' ')} ';
    String? found;
    var foundLen = 0;
    for (final e in kMarketAliases.entries) {
      if (text.contains(' ${e.key} ') && e.key.length > foundLen) {
        found = e.value;
        foundLen = e.key.length;
      }
    }
    return found;
  }
}

/// City words that name a market. Matched as whole words.
const kMarketAliases = <String, String>{
  'new york': 'nyc',
  'nyc': 'nyc',
  'ny': 'nyc',
  'new york city': 'nyc',
  'los angeles': 'la',
  'la': 'la',
  'chicago': 'chicago',
  'philadelphia': 'philly',
  'philly': 'philly',
  'dallas': 'dallas',
  'fort worth': 'dallas',
  'dfw': 'dallas',
  'houston': 'houston',
  'washington': 'dc',
  'washington dc': 'dc',
  'dc': 'dc',
  'atlanta': 'atlanta',
  'boston': 'boston',
  'miami': 'miami',
  'san francisco': 'sf',
  'sf': 'sf',
  'bay area': 'sf',
  'seattle': 'seattle',
  'phoenix': 'phoenix',
  'detroit': 'detroit',
  'minneapolis': 'minneapolis',
  'twin cities': 'minneapolis',
  'denver': 'denver',
  'cleveland': 'cleveland',
  'baltimore': 'baltimore',
  'las vegas': 'vegas',
  'san diego': 'sandiego',
  'sacramento': 'sacramento',
  'nashville': 'nashville',
  'kansas city': 'kc',
  'milwaukee': 'milwaukee',
  'cincinnati': 'cincinnati',
  'pittsburgh': 'pittsburgh',
  'portland': 'portland',
  'st louis': 'stlouis',
  'saint louis': 'stlouis',
  'salt lake city': 'slc',
};

/// Major markets: network → call sign of that city's station. Only used
/// when the guide actually lists the call sign; kept to stations the author
/// is sure of. Anything else is left for the user to assign by hand.
///
/// Affiliations change (Atlanta's did in 2025), so every entry was checked on
/// 2026-11-11 against the epgshare01 locals guide: the call sign exists and
/// its programming matches the network. Re-check before extending the table.
const kMarketStations = <String, Map<String, String>>{
  'nyc': {
    'abc': 'WABC',
    'cbs': 'WCBS',
    'nbc': 'WNBC',
    'fox': 'WNYW',
    'pbs': 'WNET',
    'cw': 'WPIX',
    'mynet': 'WWOR',
    'telemundo': 'WNJU',
    'univision': 'WXTV'
  },
  'la': {
    'abc': 'KABC',
    'cbs': 'KCBS',
    'nbc': 'KNBC',
    'fox': 'KTTV',
    'cw': 'KTLA',
    'telemundo': 'KVEA',
    'univision': 'KMEX'
  },
  'chicago': {
    'abc': 'WLS',
    'cbs': 'WBBM',
    'nbc': 'WMAQ',
    'fox': 'WFLD',
    'cw': 'WGN',
    'pbs': 'WTTW',
    'telemundo': 'WSNS',
    'univision': 'WGBO'
  },
  'philly': {
    'abc': 'WPVI',
    'cbs': 'KYW',
    'nbc': 'WCAU',
    'fox': 'WTXF',
    'pbs': 'WHYY',
    'cw': 'WPSG'
  },
  'dallas': {
    'abc': 'WFAA',
    'cbs': 'KTVT',
    'nbc': 'KXAS',
    'fox': 'KDFW',
    'cw': 'KDAF',
    'pbs': 'KERA',
    'telemundo': 'KXTX',
    'univision': 'KUVN'
  },
  'houston': {
    'abc': 'KTRK',
    'cbs': 'KHOU',
    'nbc': 'KPRC',
    'fox': 'KRIV',
    'cw': 'KIAH',
    'pbs': 'KUHT',
    'univision': 'KXLN'
  },
  'dc': {
    'abc': 'WJLA',
    'cbs': 'WUSA',
    'nbc': 'WRC',
    'fox': 'WTTG',
    'pbs': 'WETA',
    'cw': 'WDCW'
  },
  // Atlanta's CBS and CW affiliations moved in 2025 and the guide shows it:
  // left out until verified. Affiliations change; see the note above.
  'atlanta': {'abc': 'WSB', 'nbc': 'WXIA', 'fox': 'WAGA'},
  'boston': {
    'abc': 'WCVB',
    'cbs': 'WBZ',
    'nbc': 'WBTS',
    'fox': 'WFXT',
    'cw': 'WLVI',
    'pbs': 'WGBH'
  },
  'miami': {
    'abc': 'WPLG',
    'cbs': 'WFOR',
    'nbc': 'WTVJ',
    'fox': 'WSVN',
    'cw': 'WSFL',
    'pbs': 'WPBT',
    'telemundo': 'WSCV',
    'univision': 'WLTV'
  },
  'sf': {
    'abc': 'KGO',
    'cbs': 'KPIX',
    'nbc': 'KNTV',
    'fox': 'KTVU',
    'pbs': 'KQED'
  },
  'seattle': {
    'abc': 'KOMO',
    'cbs': 'KIRO',
    'nbc': 'KING',
    'fox': 'KCPQ',
    'cw': 'KSTW',
    'pbs': 'KCTS'
  },
  'phoenix': {
    'abc': 'KNXV',
    'cbs': 'KPHO',
    'nbc': 'KPNX',
    'fox': 'KSAZ',
    'cw': 'KASW',
    'pbs': 'KAET'
  },
  'detroit': {
    'abc': 'WXYZ',
    'cbs': 'WWJ',
    'nbc': 'WDIV',
    'fox': 'WJBK',
    'cw': 'WKBD',
    'pbs': 'WTVS'
  },
  'minneapolis': {
    'abc': 'KSTP',
    'cbs': 'WCCO',
    'nbc': 'KARE',
    'fox': 'KMSP',
    'cw': 'WUCW',
    'pbs': 'KTCA'
  },
  'denver': {
    'abc': 'KMGH',
    'cbs': 'KCNC',
    'nbc': 'KUSA',
    'fox': 'KDVR',
    'cw': 'KWGN',
    'pbs': 'KRMA'
  },
  'cleveland': {'abc': 'WEWS', 'cbs': 'WOIO', 'nbc': 'WKYC', 'fox': 'WJW'},
  'baltimore': {'abc': 'WMAR', 'cbs': 'WJZ', 'nbc': 'WBAL', 'fox': 'WBFF'},
  'vegas': {'abc': 'KTNV', 'cbs': 'KLAS', 'nbc': 'KSNV', 'fox': 'KVVU'},
  'sandiego': {'abc': 'KGTV', 'cbs': 'KFMB', 'nbc': 'KNSD', 'fox': 'KSWB'},
  'sacramento': {'abc': 'KXTV', 'cbs': 'KOVR', 'nbc': 'KCRA', 'fox': 'KTXL'},
  'nashville': {'abc': 'WKRN', 'cbs': 'WTVF', 'nbc': 'WSMV', 'fox': 'WZTV'},
  'kc': {'abc': 'KMBC', 'cbs': 'KCTV', 'nbc': 'KSHB', 'fox': 'WDAF'},
  'milwaukee': {'abc': 'WISN', 'cbs': 'WDJT', 'nbc': 'WTMJ', 'fox': 'WITI'},
  'cincinnati': {'abc': 'WCPO', 'cbs': 'WKRC', 'nbc': 'WLWT', 'fox': 'WXIX'},
  'pittsburgh': {'abc': 'WTAE', 'cbs': 'KDKA', 'nbc': 'WPXI', 'fox': 'WPGH'},
  'portland': {'abc': 'KATU', 'cbs': 'KOIN', 'nbc': 'KGW', 'fox': 'KPTV'},
  'stlouis': {
    'abc': 'KDNL',
    'cbs': 'KMOV',
    'nbc': 'KSDK',
    'fox': 'KTVI',
    'cw': 'KPLR'
  },
  'slc': {'abc': 'KTVX', 'cbs': 'KUTV', 'nbc': 'KSL', 'fox': 'KSTU'},
};
