import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/features/live_tv/tv_guide_screen.dart';

void main() {
  test('window always contains now, starting on a half hour', () {
    final rnd = Random(7);
    var t = DateTime(2026, 11, 14, 9);
    for (var i = 0; i < 2000; i++) {
      t = t.add(Duration(minutes: rnd.nextInt(500)));
      final (start, end) = guideWindow(t);
      expect(start.isBefore(t) || start == t, isTrue);
      expect(end.isAfter(t), isTrue);
      expect(start.minute % 30, 0);
      expect(end.difference(start), const Duration(hours: 6));
    }
  });

  test('fuzz: a long session of random scrolling and clock jumps stays valid',
      () {
    final rnd = Random(42);
    const width = 1000.0;
    var now = DateTime(2026, 11, 14, 12, 10);
    var (start, end) = guideWindow(now);
    double maxOffset() =>
        max(0.0, end.difference(start).inMinutes * 4.0 - width);
    var offset = 30 * 4.0;
    for (var i = 0; i < 20000; i++) {
      switch (rnd.nextInt(3)) {
        case 0: // Left/Right by half an hour, clamped like _scrollTimeTo
          offset = (offset + (rnd.nextBool() ? 120 : -120))
              .clamp(0.0, maxOffset());
        case 1: // the clock moves on
          now = now.add(Duration(minutes: rnd.nextInt(90)));
        case 2: // re-anchor
          final (ns, ne) = guideWindow(now);
          if (ns.isAfter(start)) {
            final momentBefore = start.add(Duration(minutes: offset ~/ 4));
            offset = guideReanchoredOffset(
                offset: offset,
                oldStart: start,
                newStart: ns,
                maxOffset: max(0.0, ne.difference(ns).inMinutes * 4.0 - width));
            start = ns;
            end = ne;
            final momentAfter = start.add(Duration(minutes: offset ~/ 4));
            // Same moment, unless the old one fell off the new window.
            if (momentBefore.isAfter(start)) {
              expect(momentAfter.difference(momentBefore).inMinutes.abs() <= 1,
                  isTrue,
                  reason: '$momentBefore vs $momentAfter');
            }
          }
      }
      expect(offset, inInclusiveRange(0.0, maxOffset()));
    }
  });
}
