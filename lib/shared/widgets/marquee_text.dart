import 'dart:async';

import 'package:flutter/material.dart';

/// A single line of text that is cut with an ellipsis, unless [active] and
/// it doesn't fit: then it slides sideways to show the rest, pauses, and
/// starts over. Used on TV where a focused box can't be tapped open.
///
/// With [maxLines] above 1 the text wraps while idle (like a plain `Text`);
/// it only turns into a single scrolling line when it is active and still
/// doesn't fit.
class MarqueeText extends StatefulWidget {
  const MarqueeText(
    this.text, {
    super.key,
    this.style,
    this.active = true,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle? style;
  final bool active;
  final int maxLines;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  static const _pause = Duration(milliseconds: 900);
  static const _pixelsPerSecond = 40.0;
  static const _gap = 24.0;

  final _controller = ScrollController();
  bool _running = false;
  int _generation = 0;

  @override
  void dispose() {
    _generation++;
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    if (_running) return;
    _running = true;
    final gen = ++_generation;
    unawaited(_loop(gen));
  }

  void _stop() {
    if (!_running) return;
    _running = false;
    _generation++;
    if (_controller.hasClients) _controller.jumpTo(0);
  }

  Future<void> _loop(int gen) async {
    bool alive() => mounted && gen == _generation;
    while (alive()) {
      await Future<void>.delayed(_pause);
      if (!alive() || !_controller.hasClients) return;
      final distance = _controller.position.maxScrollExtent;
      if (distance <= 0) return;
      await _controller.animateTo(
        distance,
        duration: Duration(
            milliseconds: (distance / _pixelsPerSecond * 1000).round()),
        curve: Curves.linear,
      );
      if (!alive()) return;
      await Future<void>.delayed(_pause);
      if (!alive() || !_controller.hasClients) return;
      _controller.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: widget.text, style: style),
        maxLines: widget.maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();

      if (!(widget.active && overflows)) {
        if (_running) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _stop();
          });
        }
        return Text(
          widget.text,
          maxLines: widget.maxLines,
          overflow: TextOverflow.ellipsis,
          style: widget.style,
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start();
      });
      return ClipRect(
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(right: _gap),
            child: Text(
              widget.text,
              maxLines: 1,
              softWrap: false,
              style: widget.style,
            ),
          ),
        ),
      );
    });
  }
}
