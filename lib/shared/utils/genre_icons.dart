import 'package:flutter/material.dart';
import 'package:open_iptv/core/services/parental_service.dart';

/// Picks an icon that fits a Live TV category or VOD genre name ("US| NEWS
/// NETWORK" → newspaper, "|EN| 4K MOVIES" → film, "CA| OHL PPV" → hockey),
/// falling back to [fallback] when nothing matches.
///
/// Same approach as the parental adult detection ([isAdultCategory]) —
/// case-insensitive keyword matching on the name — but on whole words, so
/// short keywords can't fire inside unrelated ones ("art" in "party", "news"
/// in "network").
///
/// Rules are grouped into [_Tier]s. The most specific tier with any match
/// wins (a sport beats "Sports", which beats "PPV", which beats "Network",
/// which beats a country code). Within a tier the keyword that appears
/// earliest in the name wins, so combined genres read the way they're
/// written: "Action/Thriller" → action, "Horror/Thriller" → horror.
IconData genreIcon(String name, {required IconData fallback}) {
  return _cache.putIfAbsent('$name\u0000${fallback.codePoint}', () {
    if (isAdultCategory(name)) return Icons.eighteen_up_rating_outlined;
    final variants = _variants(name);
    _Rule? best;
    var bestTier = _Tier.values.length;
    var bestPos = 1 << 30;
    for (final rule in _rules) {
      final tier = rule.tier.index;
      if (tier > bestTier) continue;
      final pos = _firstMatch(variants, rule.keywords);
      if (pos == null) continue;
      if (tier < bestTier || pos < bestPos) {
        best = rule;
        bestTier = tier;
        bestPos = pos;
      }
    }
    return best?.icon ?? fallback;
  });
}

final _cache = <String, IconData>{};

/// Earliest character offset of any keyword across the name's variants, or
/// null if none matches.
int? _firstMatch(List<String> variants, List<String> keywords) {
  int? best;
  for (final v in variants) {
    for (final kw in keywords) {
      final i = v.indexOf(' $kw ');
      if (i >= 0 && (best == null || i < best)) best = i;
    }
  }
  return best;
}

/// The name as padded, lowercased word strings (` word word `), in a few
/// spellings so brand-style names still match:
///  - as written ("disney+", "r&b", "musicchoice"),
///  - split at capitals ("MusicChoice" → "music choice", "MLBWebcast" →
///    "mlb webcast", "PlexTV" → "plex tv"),
///  - with "+" dropped ("espn+" → "espn", "paramount+" → "paramount").
List<String> _variants(String name) {
  String clean(String s) =>
      ' ${s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9+&]+'), ' ').trim()} ';
  final split = name
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAllMapped(
          RegExp(r'([A-Z])([A-Z][a-z])'), (m) => '${m[1]} ${m[2]}');
  final asWritten = clean(name);
  return [asWritten, clean(split), asWritten.replaceAll('+', ' ')];
}

/// Most specific first.
enum _Tier {
  /// A particular sport, genre or subject.
  specific,

  /// A broad kind of content: sports, movies, series, classics, top picks.
  broad,

  /// A service or packaging: streaming brands, PPV, "entertainment".
  platform,

  /// Channel groupings: broadcast networks, "TV", resolution.
  channel,

  /// Countries, regions and languages — only when nothing else says more.
  region,
}

class _Rule {
  const _Rule(this.tier, this.icon, this.keywords);
  final _Tier tier;
  final IconData icon;
  final List<String> keywords;
}

const _s = _Tier.specific;
const _b = _Tier.broad;
const _p = _Tier.platform;
const _c = _Tier.channel;
const _r = _Tier.region;

const _rules = <_Rule>[
  // ---- Kids & animation ------------------------------------------------
  _Rule(_s, Icons.child_care_outlined, [
    'kids', 'kid', 'children', 'childrens', 'junior', 'toddler', 'preschool',
    'cartoon', 'cartoons', 'toons', 'nick', 'nickelodeon', 'disney junior',
    'baby', 'babies',
  ]),
  _Rule(_s, Icons.animation, [
    'anime', 'animation', 'animated', 'adult swim', 'cartoon network',
    'pixar', 'dreamworks', 'ghibli',
  ]),

  // ---- Individual sports -------------------------------------------------
  _Rule(_s, Icons.sports_football, [
    'nfl', 'american football', 'college football', 'ncaaf', 'afl', 'cfl',
    'xfl', 'ufl',
  ]),
  _Rule(_s, Icons.sports_hockey, [
    'hockey', 'nhl', 'ahl', 'ohl', 'whl', 'qmjhl', 'khl', 'echl',
    'stanley cup',
  ]),
  _Rule(_s, Icons.sports_soccer, [
    'soccer', 'football', 'futbol', 'futebol', 'footy', 'epl',
    'premier league', 'la liga', 'laliga', 'liga', 'serie a', 'bundesliga',
    'ligue 1', 'eredivisie', 'champions league', 'europa league', 'uefa',
    'mls', 'liga mx', 'fifa', 'world cup', 'worldcup', 'cup', 'copa',
    'concacaf', 'efl', 'championship', 'league one', 'league two',
    'national league', 'spfl', 'scottish football', 'fa player', 'fa cup',
    'loi', 'league of ireland', 'nifl',
  ]),
  _Rule(_s, Icons.sports_basketball, [
    'basketball', 'nba', 'wnba', 'ncaab', 'euroleague',
  ]),
  _Rule(_s, Icons.sports_baseball, ['baseball', 'mlb', 'milb']),
  _Rule(_s, Icons.sports_golf, ['golf', 'pga', 'lpga', 'liv golf']),
  _Rule(_s, Icons.sports_tennis, ['tennis', 'atp', 'wta', 'wimbledon']),
  _Rule(_s, Icons.sports_cricket, ['cricket', 'ipl']),
  _Rule(_s, Icons.sports_rugby, [
    'rugby', 'nrl', 'super league', 'six nations',
  ]),
  _Rule(_s, Icons.sports_volleyball, ['volleyball', 'volley ball', 'volley']),
  _Rule(_s, Icons.sports_mma, [
    'boxing', 'boxe', 'ufc', 'mma', 'wwe', 'aew', 'wrestling', 'fight',
    'fighting', 'kickboxing', 'glory', 'bellator', 'pfl', 'matchroom',
    'clubber', 'fite', 'pbc',
  ]),
  _Rule(_s, Icons.sports_motorsports, [
    'racing', 'f1', 'formula 1', 'formula1', 'nascar', 'motogp', 'moto gp',
    'indycar', 'motorsport', 'motorsports', 'mxgp', 'motocross',
    'supercross', 'rally', 'wrc', 'nhra', 'tt race', 'dirtvision',
  ]),
  _Rule(_s, Icons.adjust, ['darts', 'pdc']),
  _Rule(_s, Icons.emoji_events_outlined, [
    // Sports without their own icon.
    'horse racing', 'horse', 'horses', 'equestrian', 'clipmyhorse', 'gaa',
    'hurling', 'gaelic', 'snooker', 'pool', 'billiards', 'cycling',
    'athletics', 'swimming', 'skiing', 'olympics', 'olympic',
  ]),
  _Rule(_s, Icons.sports_esports, [
    'gaming', 'esports', 'e sports', 'video games', 'gamer', 'twitch',
  ]),

  // ---- Information ------------------------------------------------------
  _Rule(_s, Icons.cloud_outlined, ['weather']),
  _Rule(_s, Icons.newspaper, [
    'news', 'noticias', 'nouvelles', 'cnn', 'msnbc', 'fox news', 'newsmax',
    'bbc news', 'sky news', 'headlines',
  ]),
  _Rule(_s, Icons.trending_up, [
    'business', 'finance', 'financial', 'money', 'markets', 'stocks',
    'bloomberg', 'cnbc',
  ]),
  _Rule(_s, Icons.account_balance_outlined, [
    'legislative', 'government', 'politics', 'political', 'parliament',
    'congress', 'cspan', 'c span', 'public',
  ]),
  _Rule(_s, Icons.gavel, ['court', 'justice', 'legal', 'law']),

  // ---- Music ------------------------------------------------------------
  _Rule(_s, Icons.radio_outlined, ['radio']),
  _Rule(_s, Icons.music_note_outlined, [
    'music', 'musica', 'musique', 'mtv', 'vh1', 'hits', 'concert',
    'concerts', 'hip hop', 'hiphop', 'r&b', 'rnb', 'rock', 'jazz', 'pop',
    'country', 'karaoke', 'musical', 'musicals', 'broadway', 'house',
    'techno', 'edm', 'dance', 'electronic', 'indie', 'reggae', 'classical',
    'blues', 'metal', 'soul', 'kpop', 'k pop', 'stingray', 'music choice',
  ]),

  // ---- Genres -----------------------------------------------------------
  _Rule(_s, Icons.dark_mode_outlined, ['horror', 'scary', 'paranormal']),
  _Rule(_s, Icons.fingerprint, [
    'crime', 'true crime', 'mystery', 'detective', 'investigation',
    'thriller', 'thrillers', 'suspense', 'mafia', 'gangster', 'gangsters',
    'mob',
  ]),
  _Rule(_s, Icons.rocket_launch_outlined, [
    'sci fi', 'scifi', 'science fiction', 'fantasy', 'fantasty', 'space',
  ]),
  _Rule(_s, Icons.sentiment_very_satisfied_outlined, [
    'comedy', 'comedies', 'sitcom', 'sitcoms', 'funny', 'standup',
    'stand up',
  ]),
  _Rule(_s, Icons.theater_comedy_outlined, [
    'drama', 'dramas', 'telenovela', 'telenovelas', 'novelas', 'soap',
    'soaps',
  ]),
  _Rule(_s, Icons.favorite_border, ['romance', 'romantic', 'love']),
  _Rule(_s, Icons.local_fire_department_outlined, ['action']),
  _Rule(_s, Icons.military_tech_outlined, ['war', 'military']),
  _Rule(_s, Icons.landscape_outlined, ['western', 'westerns', 'cowboy']),
  _Rule(_s, Icons.explore_outlined, ['adventure', 'adventures']),
  _Rule(_s, Icons.family_restroom, ['family']),
  _Rule(_s, Icons.card_giftcard_outlined, [
    'christmas', 'holiday', 'holidays', 'xmas', 'halloween',
  ]),
  _Rule(_s, Icons.video_camera_back_outlined, [
    'documentary', 'documentaries', 'docs', 'doc', 'docu', 'biography',
    'discovery',
  ]),
  _Rule(_s, Icons.history_edu_outlined, ['history', 'historical']),
  _Rule(_s, Icons.science_outlined, ['science', 'tech', 'technology']),
  _Rule(_s, Icons.school_outlined, [
    'education', 'educational', 'learning', 'learn', 'edu',
  ]),
  _Rule(_s, Icons.pets_outlined, ['animals', 'animal', 'pets', 'wildlife']),
  _Rule(_s, Icons.park_outlined, [
    'nature', 'outdoor', 'outdoors', 'hunting', 'fishing',
  ]),
  _Rule(_s, Icons.flight_takeoff, ['travel', 'tourism']),
  _Rule(_s, Icons.restaurant_outlined, [
    'cooking', 'food', 'kitchen', 'chef', 'recipes', 'culinary',
  ]),
  _Rule(_s, Icons.church_outlined, [
    'religious', 'religion', 'faith', 'christian', 'biblical', 'bible',
    'gospel', 'church', 'catholic', 'islamic', 'islam', 'quran', 'worship',
    'spiritual',
  ]),
  _Rule(_s, Icons.shopping_bag_outlined, ['shop', 'shopping', 'qvc', 'hsn']),
  _Rule(_s, Icons.fitness_center, [
    'fitness', 'health', 'workout', 'yoga', 'wellness',
  ]),
  _Rule(_s, Icons.directions_car_outlined, [
    'auto', 'autos', 'cars', 'car', 'motor', 'motors',
  ]),
  _Rule(_s, Icons.spa_outlined, [
    'relax', 'relaxing', 'ambient', 'chill', 'fireplace', 'scenic',
    'meditation', 'sleep', 'slow tv',
  ]),
  _Rule(_s, Icons.home_outlined, [
    'lifestyle', 'home', 'diy', 'garden', 'fashion', 'style',
  ]),
  _Rule(_s, Icons.videocam_outlined, ['reality']),
  _Rule(_s, Icons.bolt, [
    'comic', 'comics', 'comic book', 'superhero', 'superheroes', 'marvel',
    'dc',
  ]),
  _Rule(_s, Icons.palette_outlined, ['culture', 'arts', 'art']),
  _Rule(_s, Icons.local_activity_outlined, [
    'spectacles', 'performances', 'performance', 'theatre', 'theater',
    'opera', 'ballet',
  ]),
  _Rule(_s, Icons.recent_actors_outlined, [
    'actors', 'actor', 'actresses', 'directors', 'director', 'celebrities',
    'celebrity',
  ]),
  _Rule(_s, Icons.touch_app_outlined, ['interactive']),

  // ---- Broad content types ---------------------------------------------
  _Rule(_b, Icons.emoji_events_outlined, [
    'sports', 'sport', 'espn', 'dazn', 'bein', 'tsn', 'sn', 'sportsnet',
    'sky sports', 'eurosport', 'setanta', 'nfhs', 'flo', 'flosports', 'b1g',
    'btn', 'big ten', 'sec network', 'acc network', 'deportes', 'deporte',
    'esporte', 'esportes', 'sportif', 'ncaa',
  ]),
  _Rule(_b, Icons.camera_roll_outlined, [
    'classic', 'classics', 'retro', 'oldies', 'vintage', 'old',
  ]),
  _Rule(_b, Icons.workspace_premium_outlined, [
    'top', 'top rated', 'imdb', 'oscar', 'oscars', 'award', 'awards',
    'popular', 'trending', 'best',
  ]),
  _Rule(_b, Icons.new_releases_outlined, [
    'latest', 'new releases', 'new release', 'new released', 'releases',
    'released', 'recently added', 'premieres', 'premiere', 'just added',
  ]),
  _Rule(_b, Icons.collections_bookmark_outlined, [
    'collection', 'collections', 'library', 'box sets', 'box set',
    'franchise', 'franchises', 'saga', 'sagas',
  ]),
  _Rule(_b, Icons.movie_outlined, [
    'movies', 'movie', 'film', 'films', 'cinema', 'cinemania', 'hollywood',
    'vod', 'box office', 'boxoffice', 'peliculas', 'filmes', 'sky store',
  ]),
  _Rule(_b, Icons.tv_outlined, [
    'series', 'tv shows', 'tv show', 'shows', 'show', 'episodes', 'seasons',
  ]),

  // ---- Platforms & packaging -------------------------------------------
  _Rule(_p, Icons.smart_display_outlined, [
    'netflix', 'hulu', 'disney+', 'disney', 'apple+', 'apple tv', 'apple',
    'prime', 'prime video', 'amazon', 'hbo', 'max', 'paramount', 'peacock',
    'starz', 'showtime', 'pluto', 'plutotv', 'tubi', 'tubitv', 'samsung',
    'samsungtvplus', 'xumo', 'xumotv', 'roku', 'rokutv', 'rakuten',
    'rakutentv', 'plex', 'plextv', 'crunchyroll', 'vizio', 'freevee',
    'sling', 'fubo', 'lgtv', 'lg channels', 'tcl', 'oneplay', 'now tv',
    'stan', 'vix', 'viaplay', 'britbox', 'acorn', 'amc', 'mgm', 'shudder',
    'bet+', 'allblk', 'discovery+', 'curiosity', 'mubi', 'criterion',
  ]),
  _Rule(_p, Icons.confirmation_number_outlined, [
    'ppv', 'pay per view', 'events', 'event', 'live event', 'replays',
  ]),
  _Rule(_p, Icons.celebration_outlined, [
    'entertainment', 'variety', 'general', 'talk',
  ]),
  _Rule(_p, Icons.location_city_outlined, [
    'local', 'locals', 'regional', 'localnow',
  ]),

  // ---- Channel groupings -----------------------------------------------
  _Rule(_c, Icons.connected_tv_outlined, [
    'abc', 'cbs', 'nbc', 'fox', 'cw', 'pbs', 'telemundo', 'univision', 'itv',
    'itvx', 'bbc', 'bbci', 'bbciplayer', 'iplayer', 'channel 4', 'channel 5',
    '9now', '7plus', '10play', 'ctv', 'cbc', 'rte', 'network', 'networks',
    'channels', 'tv', 'fan made',
  ]),
  _Rule(_c, Icons.four_k_outlined, ['4k', 'uhd', '2160p', '3840p']),
  _Rule(_c, Icons.hd_outlined, ['fhd', 'hd', '1080p', '720p', 'hevc']),
  _Rule(_c, Icons.grid_view_outlined, ['all']),

  // ---- Countries, regions, languages -----------------------------------
  // Full names only — a "UK|"/"CA|" style prefix is just a label, not a
  // sign the category is about that country ("UK| MC VIDEO").
  _Rule(_r, Icons.public, [
    'world', 'international', 'foreign', 'global', 'usa', 'united states',
    'america', 'united kingdom', 'britain', 'canada', 'australia',
    'new zealand', 'ireland', 'india', 'spain', 'france', 'germany', 'italy',
    'mexico', 'brazil', 'argentina', 'chile', 'portugal', 'netherlands',
    'belgium', 'switzerland', 'austria', 'sweden', 'norway', 'denmark',
    'finland', 'poland', 'turkey', 'greece', 'korea', 'south korea', 'japan',
    'china', 'philippines', 'pakistan', 'africa', 'asia', 'europe', 'latin',
    'latino', 'caribbean', 'arab', 'arabic', 'english', 'french', 'spanish',
    'german', 'italian', 'portuguese', 'hindi', 'urdu', 'punjabi', 'tamil',
    'turkish', 'polish', 'russian',
  ]),
];
