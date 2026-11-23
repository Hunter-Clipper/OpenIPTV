import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_iptv/core/models/channel.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/features/sports/fixture_matcher.dart';
import 'package:open_iptv/features/sports/sports_catalog.dart';
import 'package:open_iptv/features/sports/sports_match_sheet.dart';
import 'package:open_iptv/features/sports/sports_models.dart';
import 'package:open_iptv/features/sports/sports_providers.dart';
import 'package:open_iptv/features/sports/sports_screen.dart';
import 'package:open_iptv/l10n/app_languages.dart';
import 'package:open_iptv/l10n/gen/app_localizations.dart';
import 'package:open_iptv/shared/theme/app_theme.dart';
import 'package:open_iptv/shared/theme/theme_preset.dart';

/// Where to write screenshots for a visual check (unset: don't write).
final _shots = Platform.environment['OPENIPTV_THEME_SHOTS'];

GameTeam _team(String name, String? score, {String? nick}) =>
    GameTeam(name: name, score: score, nickname: nick);

final _kickoff = DateTime.now().toUtc().add(const Duration(hours: 3));

SportsLeague _league(String id) => sportsLeagueById(id)!;

final _games = <Game>[
  Game(
    id: 'nhl:1',
    league: _league('nhl'),
    kickoff: DateTime.now().toUtc().subtract(const Duration(minutes: 50)),
    state: GameState.live,
    statusText: '2nd 12:14',
    title: 'Los Angeles Kings at Toronto Maple Leafs',
    away: _team('Los Angeles Kings', '2'),
    home: _team('Toronto Maple Leafs', '1'),
  ),
  Game(
    id: 'nfl:1',
    league: _league('nfl'),
    kickoff: _kickoff,
    state: GameState.upcoming,
    statusText: 'Scheduled',
    title: 'Indianapolis Colts at Houston Texans',
    away: _team('Indianapolis Colts', null),
    home: _team('Houston Texans', null),
  ),
  Game(
    id: 'nba:1',
    league: _league('nba'),
    kickoff: DateTime.now().toUtc().subtract(const Duration(hours: 5)),
    state: GameState.finished,
    statusText: 'Final/OT',
    title: 'Golden State Warriors at Memphis Grizzlies',
    away: _team('Golden State Warriors', '112'),
    home: _team('Memphis Grizzlies', '118'),
  ),
  Game(
    id: 'eng.1:1',
    league: _league('eng.1'),
    kickoff: _kickoff,
    state: GameState.upcoming,
    statusText: 'Scheduled',
    title: 'Wolverhampton Wanderers at Brighton & Hove Albion',
    away: _team('Wolverhampton Wanderers', null),
    home: _team('Brighton & Hove Albion', null),
  ),
  Game(
    id: 'f1:1',
    league: _league('f1'),
    kickoff: _kickoff,
    state: GameState.upcoming,
    statusText: '7:30 PM',
    title: 'Heineken Las Vegas Grand Prix',
  ),
];

Channel _ch(String id, String name, String group) => Channel(
      id: id,
      sourceId: 's',
      name: name,
      streamUrl: 'http://x/$id',
      sortOrder: 0,
      groupTitle: group,
    );

final _matches = <ChannelMatch>[
  ChannelMatch(
    channel: _ch('1', 'NFL : 01 - TNF 8:15pm Colts at Texans [1080p]',
        'USA: NFL PACKAGE [1080p]'),
    strength: MatchStrength.both,
    source: MatchSource.channelName,
  ),
  ChannelMatch(
    channel: _ch('2', 'US (STREAM 263): NFL Football: 2026 Week 11 Indianapolis '
        'Colts vs. Houston Texans (2026-11-20 00:30:00) [1080p]', 'USA: STREAMS'),
    strength: MatchStrength.both,
    source: MatchSource.channelName,
  ),
  ChannelMatch(
    channel: _ch('3', 'USA: CBS 9 INDIANAPOLIS', 'USA: LOCAL'),
    strength: MatchStrength.one,
    source: MatchSource.guide,
    programme: Programme(
      channelId: '3',
      start: DateTime.now().subtract(const Duration(minutes: 20)),
      end: DateTime.now().add(const Duration(hours: 2)),
      title: 'Colts Pregame Live',
    ),
    alternates: 1,
  ),
];

/// WCAG contrast ratio of two opaque colours.
double _contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final la = lum(a), lb = lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

Widget _app(ThemePreset preset, Widget home, {double textScale = 1.0}) {
  return ProviderScope(
    overrides: [
      sportsEnabledProvider.overrideWith((ref) => true),
      sportsLeaguesProvider.overrideWith((ref) => {'nhl', 'nfl', 'nba', 'eng.1', 'f1'}),
      sportsFollowedProvider.overrideWith((ref) => {'Indianapolis Colts'}),
      sportsGamesProvider.overrideWith((ref, day) async => DayGames(_games)),
      gameMatchesProvider.overrideWith((ref, game) async => _matches),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forPreset(preset),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  if (_shots == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_shots/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<void> _loadFonts() async {
  const fonts = {
    'GoogleSans': [
      'assets/fonts/google_sans/GoogleSans-Regular.ttf',
      'assets/fonts/google_sans/GoogleSans-Medium.ttf',
      'assets/fonts/google_sans/GoogleSans-SemiBold.ttf',
      'assets/fonts/google_sans/GoogleSans-Bold.ttf',
    ],
    'Nunito': [
      'assets/fonts/nunito/Nunito-Regular.ttf',
      'assets/fonts/nunito/Nunito-Bold.ttf',
    ],
    'JetBrainsMono': [
      'assets/fonts/jetbrains_mono/JetBrainsMono-Regular.ttf',
      'assets/fonts/jetbrains_mono/JetBrainsMono-Bold.ttf',
    ],
  };
  for (final e in fonts.entries) {
    final loader = FontLoader(e.key);
    for (final path in e.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  for (final preset in ThemePreset.values) {
    for (final size in const [Size(1280, 720), Size(412, 860)]) {
      final tag = '${preset.id}_${size.width.toInt()}';

      testWidgets('Sports list and sheet render in ${preset.id} at ${size.width.toInt()}px',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final key = GlobalKey();

        await tester.pumpWidget(RepaintBoundary(
            key: key, child: _app(preset, const SportsScreen())));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Live now'), findsOneWidget);
        expect(find.text('Following'), findsOneWidget);
        await _shot(tester, key, '${tag}_list');

        await tester.tap(find.text('Indianapolis Colts').first);
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.textContaining('Named for this game'), findsWidgets);
        await _shot(tester, key, '${tag}_sheet');
      });
    }

    testWidgets('Sports list fits at the largest text size in ${preset.id}',
        (tester) async {
      tester.view.physicalSize = const Size(412, 860);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: _app(preset, const SportsScreen(), textScale: 1.3)));
      await tester.pump(const Duration(milliseconds: 600));
      await _shot(tester, key, '${preset.id}_412_list_large');
      // Any RenderFlex overflow fails the test on its own.
    });

    test('contrast of the colours Sports uses in ${preset.id}', () {
      final t = AppTheme.forPreset(preset);
      final cs = t.colorScheme;
      final card = cs.surfaceContainer;
      final page = t.scaffoldBackgroundColor;
      final rows = <String, double>{
        'row title  (onSurface on card)': _contrast(cs.onSurface, card),
        'status/time (onSurfaceVariant on card)':
            _contrast(cs.onSurfaceVariant, card),
        'LIVE        (error on card)': _contrast(cs.error, card),
        'section head (primary on page)': _contrast(cs.primary, page),
        'chip label  (onSurface on page)': _contrast(cs.onSurface, page),
      };
      // ignore: avoid_print
      print('${preset.id}: ${rows.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(1)}').join(' | ')}');
      // On a light look the selected chip must not depend on what is under
      // it (a see-through tint came out dark navy under dark text).
      if (t.brightness == Brightness.light) {
        expect(t.chipTheme.selectedColor?.a ?? 1.0, 1.0,
            reason: '${preset.id} selected chip colour is see-through');
      }
      // The pieces Sports adds must stay readable (WCAG AA for text).
      expect(rows['row title  (onSurface on card)']!, greaterThan(4.5));
      expect(rows['LIVE        (error on card)']!, greaterThan(3.0));
      expect(rows['section head (primary on page)']!, greaterThan(3.0));
    });
  }
}
