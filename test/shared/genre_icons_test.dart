import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/shared/utils/genre_icons.dart';

const _fallback = Icons.folder_outlined;
IconData _icon(String name) => genreIcon(name, fallback: _fallback);

void _expectAll(Map<String, IconData> cases) =>
    cases.forEach((name, icon) => expect(_icon(name), icon, reason: name));

// Names taken from real providers' category lists.
void main() {
  test('plain genres', () {
    _expectAll({
      'News': Icons.newspaper,
      'Weather': Icons.cloud_outlined,
      'Kids': Icons.child_care_outlined,
      'Animation': Icons.animation,
      'Religious': Icons.church_outlined,
      'Cooking': Icons.restaurant_outlined,
      'Documentary': Icons.video_camera_back_outlined,
      'Legislative': Icons.account_balance_outlined,
      'General': Icons.celebration_outlined,
      'Culture': Icons.palette_outlined,
      'Interactive': Icons.touch_app_outlined,
      'Reality': Icons.videocam_outlined,
      'Comic Book': Icons.bolt,
      'Library': Icons.collections_bookmark_outlined,
    });
  });

  test('a specific sport beats generic sports, PPV and networks', () {
    _expectAll({
      'US| SOCCER PPV': Icons.sports_soccer,
      'CA| OHL PPV': Icons.sports_hockey,
      'AU| NRL TV PPV': Icons.sports_rugby,
      'UK| MATCHROOM PPV': Icons.sports_mma,
      '|SPT| SPORT BOXING': Icons.sports_mma,
      'UK| PDC BOARD PPV': Icons.adjust,
      'UK| VOLLEY BALL WORLD PPV': Icons.sports_volleyball,
      'UK| SUPERCROSS PPV': Icons.sports_motorsports,
      'UK| APPLE TV F1 PPV': Icons.sports_motorsports,
      'HR| HORSE RACING': Icons.emoji_events_outlined,
      'UK| CHAMPIONSHIP': Icons.sports_soccer,
      'UK| CUP GAMES & INTERNATIONAL': Icons.sports_soccer,
      'US| NFL NETWORK HULU': Icons.sports_football,
      'NCAAF 09: BIG TEN': Icons.sports_football,
      'US| SPORTS NETWORK': Icons.emoji_events_outlined,
      'NA| PPV & LIVE EVENTS': Icons.confirmation_number_outlined,
    });
  });

  test('combined genres use the first one named', () {
    _expectAll({
      '|EN| ACTION/THRILLER': Icons.local_fire_department_outlined,
      '|EN| HORROR/THRILLER': Icons.dark_mode_outlined,
      '|EN| DRAMA/COMEDY': Icons.theater_comedy_outlined,
      '|EN| 4K DOCUMENTARY/MUSIC/ STAND-UP': Icons.video_camera_back_outlined,
      '24/7 KIDS/FAMILY VIP': Icons.child_care_outlined,
    });
  });

  test('genre beats content type, which beats platform', () {
    _expectAll({
      'NETFLIX KIDS': Icons.child_care_outlined,
      '|EN| PIXAR MOVIES': Icons.animation,
      '|EN| CHRISTMAS MOVIES': Icons.card_giftcard_outlined,
      '4K NETFLIX MOVIES': Icons.movie_outlined,
      '|MULTI| APPLE+ SERIES': Icons.tv_outlined,
      '|EN| NETFLIX': Icons.smart_display_outlined,
      '4K RELAX UHD 3840P': Icons.spa_outlined,
      '4K UHD 3840P': Icons.four_k_outlined,
    });
  });

  test('brand-style names: "+", joined words and capitals', () {
    _expectAll({
      'US| PARAMOUNT+': Icons.smart_display_outlined,
      'CA| TSN+ PPV': Icons.emoji_events_outlined,
      'US| FIFA+ PPV': Icons.sports_soccer,
      'UK| DISCOVERY +': Icons.video_camera_back_outlined,
      '|EN| AMC+/MGM+': Icons.smart_display_outlined,
      'MusicChoice': Icons.music_note_outlined,
      'MLBWebcast - Live Channels': Icons.sports_baseball,
      'PlexTV - Australia': Icons.smart_display_outlined,
      'LocalNow': Icons.location_city_outlined,
    });
  });

  test('networks and regions', () {
    _expectAll({
      'US| ABC NETWORK': Icons.connected_tv_outlined,
      'UK| ITV X VIP': Icons.connected_tv_outlined,
      'A1xmedia - US Channels': Icons.connected_tv_outlined,
      'AU| AUSTRALIA': Icons.public,
      'CA| FRENCH': Icons.public,
      'DrewLiveStreams - United States': Icons.public,
    });
  });

  test('adult uses the 18+ icon, with the same detection as the lock', () {
    expect(_icon('XXX - Movies'), Icons.eighteen_up_rating_outlined);
    expect(_icon('18| FOR ADULTS'), Icons.eighteen_up_rating_outlined);
    expect(_icon('DrewLive Adult Swim 24/7'), Icons.animation);
  });

  test('matches whole words only', () {
    expect(_icon('Party Time'), _fallback); // "art" in "party"
    expect(_icon('Doctor Who'), _fallback); // "doc" in "doctor"
  });

  test('a country prefix alone is not a match', () {
    expect(_icon('UK| MC VIDEO'), _fallback);
  });

  test('unmatched names keep the fallback', () {
    expect(_icon('Uncategorized'), _fallback);
    expect(genreIcon('Undefined', fallback: Icons.category_outlined),
        Icons.category_outlined);
  });
}
