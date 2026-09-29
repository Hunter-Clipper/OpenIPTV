import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/shared/utils/display_name.dart';

void main() {
  void check(Map<String, String> cases) => cases.forEach(
      (raw, want) => expect(cleanDisplayName(raw), want, reason: raw));

  test('strips provider tags', () {
    check({
      '|EN| HORROR/THRILLER': 'Horror / Thriller',
      '|MULTI| APPLE+ SERIES': 'Apple+ Series',
      '| DOC | ENGLISH DOCUMENTARY': 'English Documentary',
      '|VOD | ENGLISH NETFLIX PRODUCED': 'English Netflix Produced',
      'US| NEWS NETWORK': 'News Network',
      '4K| SKY SPORTS MAIN EVENTS UHD': 'Sky Sports Main Events UHD',
      '18| FOR ADULTS': 'For Adults',
      'EN| CHRISTMAS 1 4K': 'Christmas 1 4K',
      'A+ - Billie Eilish: The World\'s A Little Blurry (2021)':
          'Billie Eilish: The World\'s A Little Blurry (2021)',
      'EN - The King\'s Speech (2010)': 'The King\'s Speech (2010)',
      'NF - Friends: The Reunion (2021)': 'Friends: The Reunion (2021)',
      '01 EN - Friday The 13th': '01 Friday The 13th',
      '|EN| PRE-RELEASES/SD CAM': 'Pre-Releases/SD Cam',
      '12 FR - Le Dîner de Cons': '12 Le Dîner de Cons',
      '90 DAY - The Last Resort': '90 DAY - The Last Resort',
    });
  });

  test('drops superscript decorations', () {
    check({
      'US| MAX ESPN ᴴᴰ/ᴿᴬᵂ ⁶⁰ᶠᵖˢ': 'Max ESPN',
      '24/7 DISNEY+ ᴿᴬᵂ ⁶⁰ᶠᵖˢ': '24/7 Disney+',
      '###### Relax 3840p ######': 'Relax 3840p',
      '=== LIVE SPORTS ===': 'Live Sports',
    });
  });

  test('title-cases ALL CAPS but keeps acronyms and resolutions', () {
    check({
      '4K UHD 3840P': '4K UHD 3840p',
      '24/7 CARTOON VIP': '24/7 Cartoon VIP',
      'NA| PPV & LIVE EVENTS': 'PPV & Live Events',
      'UK| ITV X VIP': 'ITV X VIP',
      'CA| SN+ PPV': 'SN+ PPV',
      'TOP IMDB/OSCAR MOVIES': 'Top IMDb / Oscar Movies',
      '|EN| STAND-UP COMEDY': 'Stand-Up Comedy',
      'US| B/R MAX SPORTS PPV': 'B/R Max Sports PPV',
      'THE LORD OF THE RINGS': 'The Lord of the Rings',
    });
  });

  test('leaves mixed-case names alone apart from tags', () {
    check({
      'DrewLive Adult Swim 24/7': 'DrewLive Adult Swim 24/7',
      'A1xmedia - US Sports': 'A1xmedia - US Sports',
      'DrewFX - Hip Hop & R&B': 'DrewFX - Hip Hop & R&B',
      'Adventure Earth (1080p)': 'Adventure Earth (1080p)',
    });
  });

  test('never returns an empty name', () {
    expect(cleanDisplayName('US|'), 'US|');
    expect(cleanDisplayName('  '), '');
  });
}
