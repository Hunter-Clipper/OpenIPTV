import '../../core/models/channel.dart';
import '../../core/models/programme.dart';

/// One game from a fixtures source, already normalised by the data layer.
class Fixture {
  const Fixture({
    required this.id,
    required this.home,
    required this.away,
    required this.kickoff,
    this.league = '',
    this.homeNames = const [],
    this.awayNames = const [],
    this.homePlace,
    this.awayPlace,
    this.eventTitle = '',
  });

  final String id;
  final String home;
  final String away;
  final String league;

  /// Kickoff in UTC.
  final DateTime kickoff;

  /// Other names for each side: short names and nicknames ("Colts").
  final List<String> homeNames;
  final List<String> awayNames;

  /// The city or region ("Indianapolis"). Only counts together with a
  /// nickname, never alone.
  final String? homePlace;
  final String? awayPlace;

  /// For events without two sides (a Grand Prix, a tennis tournament):
  /// the event's name. [home] and [away] are empty then.
  final String eventTitle;
}

enum MatchStrength {
  /// Both teams (or the full event name) were found.
  both,

  /// Only one team was found.
  one,
}

enum MatchSource {
  /// A guide entry that names the game.
  guide,

  /// A channel whose own name names the game ("NFL : 01 - 8:15pm Colts at
  /// Texans").
  channelName,
}

class ChannelMatch {
  const ChannelMatch({
    required this.channel,
    required this.strength,
    required this.source,
    this.programme,
    this.alternates = 0,
  });

  final Channel channel;
  final MatchStrength strength;
  final MatchSource source;

  /// The guide entry that matched, when [source] is the guide.
  final Programme? programme;

  /// How many other variants of the same channel (other qualities) were
  /// folded into this one.
  final int alternates;
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, //
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

final _isoDate = RegExp(r'(\d{4})-(\d{2})-(\d{2})');
final _monthDay = RegExp(
  r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2})\b',
  caseSensitive: false,
);
final _slashDate = RegExp(r'\b(\d{1,2})/(\d{1,2})\b');

/// Dates written into a channel name, as UTC midnights: `2026-11-19`,
/// `Nov 19`, `11/19`. Without a year, the one nearest [now] is used. Names
/// like "8:15pm" carry no date and give an empty list.
List<DateTime> extractNameDates(String name, {required DateTime now}) {
  final out = <DateTime>[];

  DateTime? nearest(int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    DateTime? best;
    for (final year in [now.year - 1, now.year, now.year + 1]) {
      final d = DateTime.utc(year, month, day);
      if (best == null ||
          d.difference(now).abs() < best.difference(now).abs()) {
        best = d;
      }
    }
    return best;
  }

  for (final m in _isoDate.allMatches(name)) {
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) continue;
    out.add(DateTime.utc(int.parse(m.group(1)!), month, day));
  }
  for (final m in _monthDay.allMatches(name)) {
    final d =
        nearest(_months[m.group(1)!.toLowerCase()]!, int.parse(m.group(2)!));
    if (d != null) out.add(d);
  }
  for (final m in _slashDate.allMatches(name)) {
    final d = nearest(int.parse(m.group(1)!), int.parse(m.group(2)!));
    if (d != null) out.add(d);
  }
  return out;
}

const _folds = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'å': 'a', 'ã': 'a', 'é': 'e', //
  'è': 'e', 'ê': 'e', 'ë': 'e', 'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ø': 'o', 'ú': 'u',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ñ': 'n', 'ç': 'c', 'ß': 'ss', 'ł': 'l',
  'š': 's', 'ž': 'z', 'č': 'c', 'ř': 'r', 'ý': 'y',
};

/// Seed aliases, normalised form on the right. Extended by the data layer.
const _aliases = {
  'man utd': 'manchester united',
  'man united': 'manchester united',
  'man city': 'manchester city',
  'spurs': 'tottenham hotspur',
  'tottenham': 'tottenham hotspur',
  'wolves': 'wolverhampton wanderers',
  'newcastle': 'newcastle united',
  'forest': 'nottingham forest',
  'brighton': 'brighton and hove albion',
  'inter': 'inter milan',
  'psg': 'paris saint germain',
  'la lakers': 'los angeles lakers',
  'la clippers': 'los angeles clippers',
};

/// Words that make a guide entry read like sport.
const _sportWords = {
  'nfl', 'nba', 'mlb', 'nhl', 'mls', 'wnba', 'ncaa', 'football', 'soccer', //
  'basketball', 'baseball', 'hockey', 'game', 'match', 'live', 'vs', 'versus',
  'playoff', 'playoffs', 'league', 'cup', 'sports', 'sport',
};

/// Capitalised words after a "vs" that are not a team.
const _fillerWords = {
  'live', 'game', 'match', 'tonight', 'today', 'pregame', 'postgame', //
  'from', 'the', 'watch', 'new', 'special', 'coverage', 'sunday', 'monday',
  'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'night',
  'afternoon', 'morning', 'evening', 'week', 'highlights',
};

final _versus = RegExp(
  r'\s(?:vs\.?|v|versus|at|@)\s(?!\d{1,2}(?::\d{2})?\s*(?:am|pm)?\b)',
  caseSensitive: false,
);

const _noiseWords = {'fc', 'afc', 'cf', 'sc', 'the', 'club'};

String _normalizeText(String raw) {
  final b = StringBuffer();
  for (final r in raw.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    b.write(_folds[ch] ?? ch);
  }
  return b
      .toString()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && !_noiseWords.contains(w))
      .join(' ');
}

/// Lower-cases, folds accents, drops punctuation and club-type noise words
/// (FC, AFC...), and applies the alias table.
String normalizeTeam(String raw) {
  final joined = _normalizeText(raw);
  return _aliases[joined] ?? joined;
}

/// Whether [text] mentions [team] as whole words.
bool mentionsTeam(String team, String text) {
  final t = normalizeTeam(team);
  if (t.isEmpty) return false;
  final hay = ' ${_normalizeText(text)} ';
  if (hay.contains(' $t ')) return true;
  // The text may use an alias for the team ("Man Utd" for the full name).
  for (final e in _aliases.entries) {
    if (e.value == t && hay.contains(' ${e.key} ')) return true;
  }
  return false;
}

/// How well [text] names one side: 2 = clearly (full name, a multi-word
/// short name, or nickname plus city), 1 = a one-word nickname alone, 0 =
/// not at all.
int _sideLevel(String name, List<String> aliases, String? place, String text) {
  if (name.isEmpty) return 0;
  if (mentionsTeam(name, text)) return 2;
  var nickname = false;
  for (final a in aliases) {
    if (a.isEmpty || !mentionsTeam(a, text)) continue;
    if (normalizeTeam(a).contains(' ')) return 2;
    nickname = true;
  }
  if (nickname &&
      place != null &&
      place.isNotEmpty &&
      mentionsTeam(place, text)) {
    return 2;
  }
  return nickname ? 1 : 0;
}

const _eventStopwords = {
  'grand',
  'prix',
  'gp',
  'atp',
  'wta',
  'fight',
  'night',
  'ufc',
  'the',
  'of',
  'and',
  'open',
  'championship',
  'championships',
  'tour',
  'race',
  'round',
};

/// Whether [text] names the event [title] (a race, a tournament): most of
/// its distinctive words appear. A one-word event needs that word.
bool mentionsEvent(String title, String text) {
  final key = _normalizeText(title)
      .split(' ')
      .where((w) => w.isNotEmpty && !_eventStopwords.contains(w))
      .toSet();
  if (key.isEmpty) return false;
  final have = _normalizeText(text).split(' ').toSet();
  final need = (key.length * 0.6).ceil().clamp(1, key.length);
  return key.where(have.contains).length >= need;
}

/// Strips provider noise from a channel name so quality variants group
/// together: country prefix, symbols, bracketed tags.
String channelBaseName(String name) {
  var s = name.replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)'), ' ');
  s = s.replaceFirst(RegExp(r'^\s*[A-Za-z]{2,3}\s*:\s*'), '');
  s = s.replaceAll(RegExp(r'[^A-Za-z0-9+ ]'), ' ');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

/// Higher is better; read from the tags in the name.
int channelQuality(String name) {
  final n = name.toUpperCase();
  if (n.contains('4K')) return 4;
  if (n.contains('1080')) return 3;
  if (n.contains('720')) return 2;
  if (n.contains('480')) return 1;
  return 2;
}

/// Programmes about a game rather than the game: they only ever count as
/// a possible match.
final _aboutTheGame = RegExp(
  r'pre-?game|post-?game|countdown|preview|recap|highlight|replay|tonight|'
  r'fantasy|studio|press conference|draft|\bnews\b',
  caseSensitive: false,
);

class FixtureMatcher {
  const FixtureMatcher({
    this.kickoffWindow = const Duration(minutes: 30),
    this.nameDateTolerance = const Duration(days: 1),
  });

  /// How far a guide entry's start may be from kickoff (or it must be
  /// airing at kickoff).
  final Duration kickoffWindow;

  /// A date written in a channel's name may differ from kickoff's date by
  /// this much. Wide on purpose: the provider's time zone is unknown, and
  /// the teams are what identify the game.
  final Duration nameDateTolerance;

  /// Ranks the channels that probably carry [fixture]. [programmes] are
  /// guide entries around kickoff (any channel); [channels] are the active
  /// playlist's candidate channels: guide hits are looked up in them by id,
  /// and every one is also checked by its own name.
  List<ChannelMatch> match(
    Fixture fixture, {
    required Iterable<Channel> channels,
    required Iterable<Programme> programmes,
    required DateTime now,
  }) {
    final byId = {for (final c in channels) c.id: c};
    final found = <ChannelMatch>[];

    for (final p in programmes) {
      final c = byId[p.channelId];
      if (c == null) continue;
      final airingAtKickoff =
          !p.start.isAfter(fixture.kickoff) && p.end.isAfter(fixture.kickoff);
      final nearKickoff =
          p.start.difference(fixture.kickoff).abs() <= kickoffWindow;
      if (!airingAtKickoff && !nearKickoff) continue;
      // A local station's "NFL Football" names the teams only in its
      // description, so title and description are read together.
      final text = [p.title, p.description, p.category]
          .whereType<String>()
          .where((t) => t.isNotEmpty)
          .join(' | ');
      var strength = _strength(fixture, text, nicknameAlone: false);
      if (strength == null) continue;
      if (strength == MatchStrength.one && !_looksLikeSport(fixture, text)) {
        continue;
      }
      if (_aboutTheGame.hasMatch(p.title)) strength = MatchStrength.one;
      found.add(ChannelMatch(
          channel: c,
          strength: strength,
          source: MatchSource.guide,
          programme: p));
    }

    final kickoffDay = DateTime.utc(
        fixture.kickoff.year, fixture.kickoff.month, fixture.kickoff.day);
    for (final c in channels) {
      // A lone nickname ("Blues") is too common in channel names.
      final strength = _strength(fixture, c.name, nicknameAlone: false);
      if (strength == null) continue;
      final dates = extractNameDates(c.name, now: now);
      if (dates.isNotEmpty &&
          !dates.any(
              (d) => d.difference(kickoffDay).abs() <= nameDateTolerance)) {
        continue; // a different day's game
      }
      found.add(ChannelMatch(
          channel: c, strength: strength, source: MatchSource.channelName));
    }

    return _rank(_foldVariants(found));
  }

  MatchStrength? _strength(Fixture f, String text,
      {required bool nicknameAlone}) {
    if (f.home.isEmpty && f.away.isEmpty) {
      return mentionsEvent(f.eventTitle, text) ? MatchStrength.both : null;
    }
    final h = _sideLevel(f.home, f.homeNames, f.homePlace, text);
    final a = _sideLevel(f.away, f.awayNames, f.awayPlace, text);
    if (h > 0 && a > 0) return MatchStrength.both;
    final best = h > a ? h : a;
    if (best == 0) return null;
    if (!(best == 2 || nicknameAlone)) return null;
    if (_isOtherGame(f, text)) return null;
    return MatchStrength.one;
  }

  /// A one-team hit in a guide entry only counts when the entry reads like
  /// sport: the league or a sport word is in it. "Giants" in a cooking show
  /// is not a game.
  bool _looksLikeSport(Fixture f, String text) {
    final hay = ' ${_normalizeText(text)} ';
    for (final w in _sportWords) {
      if (hay.contains(' $w ')) return true;
    }
    for (final w in _normalizeText(f.league).split(' ')) {
      if (w.length >= 3 && hay.contains(' $w ')) return true;
    }
    return false;
  }

  /// "Texans vs Titans": one of our teams is named, but against somebody
  /// else, so it is a different game. Only fires when the text has a clear
  /// two-sided "X vs Y" shape and the side without our team names a team
  /// (a capitalised word that is no sport or filler word).
  bool _isOtherGame(Fixture f, String text) {
    final parts = text.split(_versus);
    if (parts.length != 2) return false;
    bool ours(String side) =>
        _sideLevel(f.home, f.homeNames, f.homePlace, side) > 0 ||
        _sideLevel(f.away, f.awayNames, f.awayPlace, side) > 0;
    final left = parts[0], right = parts[1];
    final l = ours(left), r = ours(right);
    if (l == r) return false; // both ours or neither: not this shape
    final other = l ? right : left;
    // The leading words of a side may be a title ("NFL Football: Texans"),
    // so judge the side that does NOT hold our team by its first words.
    final words = other
        .split(RegExp(r"[^A-Za-z']+"))
        .where((w) => w.length >= 3 && w[0] == w[0].toUpperCase())
        .where((w) => !_sportWords.contains(w.toLowerCase()))
        .where((w) => !_fillerWords.contains(w.toLowerCase()));
    return words.isNotEmpty;
  }

  /// Keeps the best quality of each guide channel (same base name).
  /// Name-matched channels are each their own entry.
  List<ChannelMatch> _foldVariants(List<ChannelMatch> all) {
    final groups = <String, List<ChannelMatch>>{};
    for (final m in all) {
      final key = m.source == MatchSource.channelName
          ? 'n:${m.channel.id}'
          : 'g:${channelBaseName(m.channel.name)}';
      groups.putIfAbsent(key, () => []).add(m);
    }
    return [
      for (final g in groups.values)
        () {
          g.sort((a, b) {
            final s = a.strength.index.compareTo(b.strength.index);
            if (s != 0) return s;
            return channelQuality(b.channel.name)
                .compareTo(channelQuality(a.channel.name));
          });
          final top = g.first;
          return ChannelMatch(
            channel: top.channel,
            strength: top.strength,
            source: top.source,
            programme: top.programme,
            alternates: g.length - 1,
          );
        }(),
    ];
  }

  List<ChannelMatch> _rank(List<ChannelMatch> list) {
    int score(ChannelMatch m) =>
        (m.strength == MatchStrength.both ? 100 : 0) +
        (m.source == MatchSource.channelName ? 20 : 10) +
        (m.channel.isFavorite ? 5 : 0) +
        (m.channel.hasCatchup ? 2 : 0) +
        channelQuality(m.channel.name);
    return list..sort((a, b) => score(b).compareTo(score(a)));
  }
}
