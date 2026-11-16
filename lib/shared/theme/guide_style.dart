import 'package:flutter/material.dart';
import 'package:open_iptv/shared/utils/genre_colors.dart';

/// How the TV guide dresses itself in a look that has its own idea of it
/// (Retro Cable, #178). A look without one leaves the guide as it is: the
/// guide reads `Theme.of(context).extension<GuideStyle>()` and uses its normal
/// colours when that is null.
@immutable
class GuideStyle extends ThemeExtension<GuideStyle> {
  const GuideStyle({
    required this.cellColor,
    required this.cellText,
    required this.genreColors,
    required this.focusFill,
    required this.focusText,
    required this.channelColumn,
    required this.channelText,
    required this.headerGradient,
    required this.headerText,
    required this.titleColor,
    required this.nowColor,
    this.cellRadius = 0,
  });

  /// A plain cell, and the text on it.
  final Color cellColor;
  final Color cellText;

  /// Cell colour per kind of programme, and the text on each.
  final Map<GenreBucket, ({Color fill, Color text})> genreColors;

  /// The cell the remote is on.
  final Color focusFill;
  final Color focusText;

  /// The channel name column (a light block) and its text.
  final Color channelColumn;
  final Color channelText;

  /// The panels at the top and the time strip.
  final Gradient headerGradient;
  final Color headerText;

  /// Programme title in the top panel, and the "now" line.
  final Color titleColor;
  final Color nowColor;

  final double cellRadius;

  /// Fill and text for a programme of [bucket].
  ({Color fill, Color text}) colorsFor(GenreBucket bucket) =>
      genreColors[bucket] ?? (fill: cellColor, text: cellText);

  @override
  GuideStyle copyWith() => this;

  @override
  GuideStyle lerp(ThemeExtension<GuideStyle>? other, double t) => this;
}
