import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/shared/utils/display_name.dart';

void main() {
  void check(Map<String, String> cases) => cases.forEach(
      (raw, want) => expect(cleanDisplayName(raw), want, reason: raw));

  test('strips provider tags', () {
    check({
      '|EN| HORROR/THRILLER': 'Horror / Thriller',
      '|MULTI| APPLE+ SERIES': 'Apple+ Series (Multi)',
      '| DOC | ENGLISH DOCUMENTARY': 'English Documentary',
      '|VOD | ENGLISH NETFLIX PRODUCED': 'English Netflix Produced',
      'US| NEWS NETWORK': 'News Network (USA)',
      '4K| SKY SPORTS MAIN EVENTS UHD': 'Sky Sports Main Events 4K',
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
      'US| MAX ESPN ᴴᴰ/ᴿᴬᵂ ⁶⁰ᶠᵖˢ': 'Max ESPN (USA)',
      '24/7 DISNEY+ ᴿᴬᵂ ⁶⁰ᶠᵖˢ': '24/7 Disney+',
      '###### Relax 3840p ######': 'Relax 3840p',
      '=== LIVE SPORTS ===': 'Live Sports',
    });
  });

  test('title-cases ALL CAPS but keeps acronyms and resolutions', () {
    check({
      '4K UHD 3840P': '4K UHD 3840p',
      '24/7 CARTOON VIP': '24/7 Cartoon VIP',
      'NA| PPV & LIVE EVENTS': 'PPV & Live Events (NA)',
      'UK| ITV X VIP': 'ITV X VIP (UK)',
      'CA| SN+ PPV': 'SN+ PPV (CAN)',
      'TOP IMDB/OSCAR MOVIES': 'Top IMDb / Oscar Movies',
      '|EN| STAND-UP COMEDY': 'Stand-Up Comedy',
      'US| B/R MAX SPORTS PPV': 'B/R Max Sports PPV (USA)',
      'THE LORD OF THE RINGS': 'The Lord of the Rings',
    });
  });

  test('leaves mixed-case names alone apart from tags', () {
    check({
      'DrewLive Adult Swim 24/7': 'DrewLive Adult Swim 24/7',
      'A1xmedia - US Sports': 'A1xmedia - US Sports',
      'DrewFX - Hip Hop & R&B': 'DrewFX - Hip Hop & R&B',
      'Adventure Earth (1080p)': 'Adventure Earth',
    });
  });

  test('never returns an empty name', () {
    expect(cleanDisplayName('US|'), 'US|');
    expect(cleanDisplayName('  '), '');
  });

  // Names in the style of a provider that writes "USA: NAME [1080p]".
  test('moves a country / source prefix to the end', () {
    check({
      'USA: EXAMPLE NETWORK [1080p]': 'Example Network (USA)',
      'UK: SAMPLE SPORTS [720p]': 'Sample Sports (UK)',
      'CAN: DEMO NEWS [1080p]': 'Demo News (CAN)',
      'GLOBAL: [4K-Q] SAMPLE MOVIES': 'Sample Movies 4K (Global)',
      'TUBI: TEST KITCHEN  [1080p]': 'Test Kitchen (Tubi)',
      'MULTI: EXAMPLE KIDS [1080p]': 'Example Kids (Multi)',
      // Language / type prefixes are simply dropped.
      'EN: ACTION/THRILLER [1080p]': 'Action / Thriller',
      'TV: EXAMPLE DRAMA  [1080p]': 'Example Drama',
      // Anything else with a colon is a real title.
      'NFL TEAMS: EXAMPLE EAGLES': 'NFL Teams: Example Eagles',
      'Mission: Impossible': 'Mission: Impossible',
    });
  });

  test('drops quality tags, keeps 4K, friendly 24/7 and Events', () {
    check({
      'EN - Sample Film (2020) [1080p]': 'Sample Film (2020)',
      'EN - Sample Film [4K-Q] (1981)': 'Sample Film (1981) 4K',
      'NF - Example Show [720p]': 'Example Show',
      'BTN+ 48 [720p] (D)': 'BTN+ 48 (D)',
      'Sample Show [H265]': 'Sample Show',
      '[24/7 O-D] THE EXAMPLE SHOW [1080p]': '24/7 The Example Show',
      'USA: [24/7 O-D] SAMPLE COMEDY [EXTRA] [1080p]':
          '24/7 Sample Comedy (USA)',
      'USA: EXAMPLE+ [PPV EVENTS] [1080p]': 'Example+ Events (USA)',
      'USA: DEMO SPORTS[PPV EVENTS] [1080p]': 'Demo Sports Events (USA)',
      'EN - Sample Film (2020) ([480p])': 'Sample Film (2020)',
      '[480p]/CAM - Sample Film (2026)': 'Sample Film (2026)',
    });
  });

  test('tidies live event channels', () {
    check({
      'US (EXMP+ 024): Soccer: Reds vs. Blues (Reds vs. Blues) '
              '(2026-11-01 09:45:00) [1080p]':
          'Soccer: Reds vs. Blues (2026-11-01 09:45:00)',
      '(SAMP 253): hockey:  Foxes vs Bears (Home) (2026-11-01 16:15:05) '
              '[1080p]':
          'hockey: Foxes vs Bears (Home) (2026-11-01 16:15:05)',
      '- THE EVENT HAS NOT BEGUN -:  : USA: ESPN+ [PPV EVENTS] 352 [1080p]':
          'ESPN+ Events 352 (USA) - Not started',
      '11/2 - SAMPLE FC: Mon 02 Nov 17:00 EST (US):  : USA: ESPN+ '
              '[PPV EVENTS] 181 [1080p]':
          // Mixed case: only tags and wrappers change, not the capitals.
          '11/2 - SAMPLE FC: Mon 02 Nov 17:00 EST (US): ESPN+ Events 181 (USA)',
      // An empty slot shows its name, not its placeholder date.
      '(Demo+ 059):  (2098-12-31 08:00:58) [1080p]': 'Demo+ 059',
    });
  });

  test('drops star runs and keeps call letters and "the" after a number', () {
    check({
      '✶⋆✶ EXAMPLE HAWAII ✶⋆✶ [1080p]': 'Example Hawaii',
      'USA: ABC 18 SAMPLETOWN MT (KWYB) [1080p]':
          'ABC 18 Sampletown MT (KWYB) (USA)',
      '24/7 THE EXAMPLE SHOW': '24/7 The Example Show',
      'EXAMPLE SHOW: THE CHAMPIONS': 'Example Show: The Champions',
    });
  });

  // The same standard for every provider style, shown with invented names.
  group('one standard for every naming style', () {
    test('pipe style: US| NAME HD', () {
      check({
        'US| EXAMPLE NETWORK HD': 'Example Network (USA)',
        'UK| SAMPLE SPORTS MAIN EVENT UHD/4K': 'Sample Sports Main Event 4K (UK)',
        '4k| DEMO CHANNEL UHD/4K': 'Demo Channel 4K',
        'FR| EXEMPLE TV FHD': 'Exemple TV (FR)',
        'UK| EXAMPLE MOVIES HEVC': 'Example Movies (UK)',
        'CA| EXAMPLE NEWS HD': 'Example News (CAN)',
        '|EN| 4K DOCUMENTARY/MUSIC': '4K Documentary / Music',
        '|MULTI| EXAMPLE SERIES 4K': 'Example Series 4K (Multi)',
        'EN - Example Film (2022)': 'Example Film (2022)',
        'EN - Example Film 4K (2025)': 'Example Film (2025) 4K',
        'NF - Example Show': 'Example Show',
      });
    });

    test('colon style: USA: NAME [1080p]', () {
      check({
        'USA: EXAMPLE NETWORK [1080p]': 'Example Network (USA)',
        'UK: [24/7 O-D] SAMPLE MOVIES [1080p]': '24/7 Sample Movies (UK)',
        'EN - Example Film [4K-Q] (1981)': 'Example Film (1981) 4K',
      });
    });

    test('iptv-org style: Name (1080p) [Not 24/7]', () {
      check({
        'Example Channel (1080p) [Not 24/7]': 'Example Channel',
        'Sample TV (576i)': 'Sample TV',
        'Demo Channel (720p) [Geo-blocked]': 'Demo Channel [Geo-blocked]',
        'Demo Channel (720p) [Not 24/7;Geo-blocked]':
            'Demo Channel [Geo-blocked]',
        'Example Kids (United Kingdom) (576p)': 'Example Kids (UK)',
        'Sample TV (Peru) (720p)': 'Sample TV (Peru)',
        'Example Sport HD': 'Example Sport',
        'Example Sport 2 Telugu HD (576p)': 'Example Sport 2 Telugu',
      });
    });

    test('leaves real titles and unknown markers alone', () {
      check({
        'Mission: Impossible (1996)': 'Mission: Impossible (1996)',
        'NFL TEAMS: EXAMPLE EAGLES': 'NFL Teams: Example Eagles',
        'UEFA: EXAMPLE CUP': 'UEFA: Example Cup',
        'Example Show (Home)': 'Example Show (Home)',
        'Example College (PA) vs Sample (VA)':
            'Example College (PA) vs Sample (VA)',
        '[X][Studio] Example Title': '[X][Studio] Example Title',
        '90 DAY - The Last Resort': '90 DAY - The Last Resort',
      });
    });

    test('live event states and parts', () {
      check({
        'ENDED | EXAMPLE FC - SAMPLE UNITED | Sun 01 Nov 08:03 UTC (UK) | '
                '8K EXCLUSIVE | UK: EXAMPLE PPV 8':
            'EXAMPLE FC - SAMPLE UNITED - Sun 01 Nov 08:03 UTC (UK) - '
                'EXAMPLE PPV 8 (UK) - Ended',
        'AR: DAZN PPV 1 - NO EVENT STREAMING - | 8K EXCLUSIVE':
            'DAZN PPV 1 (AR) - Not started',
      });
    });
  });
}
