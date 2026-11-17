import 'package:flutter/material.dart';
import 'package:open_iptv/shared/theme/flat_theme.dart';
import 'package:open_iptv/shared/theme/guide_style.dart';
import 'package:open_iptv/shared/utils/genre_colors.dart';

/// Retro Cable (#178): a deep-blue, flat, chunky look in the spirit of old
/// cable-box guides: blue panels, a cream channel column, bold rounded type,
/// colour-coded programme cells, a white block for the focus. Only the feel
/// is borrowed; no brand names, logos or artwork.
class RetroCable {
  RetroCable._();

  static const fontFamily = 'Nunito';

  static const navy = Color(0xFF0A2268); // the page
  static const panel = Color(0xFF123C9C); // cards, sheets
  static const panelHigh = Color(0xFF1B4DC0); // inputs, chips
  static const edge = Color(0xFF5B7FD6); // outlines
  static const cream = Color(0xFFEDE6C9); // channel column
  static const yellow = Color(0xFFFFE066); // titles, selection
  static const text = Color(0xFFF6F8FF);
  static const textDim = Color(0xFFC6D4F6);
  static const error = Color(0xFFFF8A80);

  // Programme cell colours.
  static const cellBlue = Color(0xFF2452BD);
  static const sportsGreen = Color(0xFF2E8B3E);
  static const moviePurple = Color(0xFF6B34B0);
  static const kidsYellow = Color(0xFFE6D24A);
  static const newsBlue = Color(0xFF1F6FB8);

  static const guide = GuideStyle(
    cellColor: cellBlue,
    cellText: text,
    genreColors: {
      GenreBucket.sports: (fill: sportsGreen, text: Colors.white),
      GenreBucket.movies: (fill: moviePurple, text: Colors.white),
      GenreBucket.kids: (fill: kidsYellow, text: Color(0xFF1B1B00)),
      GenreBucket.news: (fill: newsBlue, text: Colors.white),
    },
    focusFill: Colors.white,
    focusText: navy,
    channelColumn: cream,
    channelText: navy,
    headerGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF2F63D8), Color(0xFF0E3590)],
    ),
    headerText: text,
    titleColor: yellow,
    nowColor: yellow,
    logoShadow: Color(0xB30A2268),
    retroFlair: true,
  );

  /// The whole app's theme: the normal component styling, re-coloured and
  /// re-typed, with square-ish corners.
  static ThemeData theme() => buildFlatTheme(const FlatPalette(
        fontFamily: fontFamily,
        background: navy,
        panel: panel,
        panelLow: Color(0xFF0E2D80),
        panelHigh: panelHigh,
        edge: edge,
        text: text,
        textDim: textDim,
        primary: yellow,
        onPrimary: navy,
        title: yellow,
        error: error,
        guide: guide,
      ));
}
