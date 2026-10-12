import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/features/player/multi_view.dart';

void main() {
  const screen = Size(1920, 1080);
  const left = Offset(-1, 0), right = Offset(1, 0);
  const up = Offset(0, -1), down = Offset(0, 1);

  group('multiViewLayout', () {
    test('2 channels sit side by side, full height', () {
      final r = multiViewLayout(screen, 2, featured: false);
      expect(r, hasLength(2));
      expect(r[0].left, 0);
      expect(r[0].height, screen.height);
      expect(r[1].left, greaterThan(r[0].right));
      expect(r[1].right, closeTo(screen.width, 0.01));
    });

    test('4 channels make a 2×2 grid', () {
      final r = multiViewLayout(screen, 4, featured: false);
      expect(r[0].top, r[1].top);
      expect(r[2].top, r[3].top);
      expect(r[2].top, greaterThan(r[0].bottom));
    });

    test('one big: the first fills two thirds, the rest stack beside it', () {
      final r = multiViewLayout(screen, 3, featured: true);
      expect(r[0].height, screen.height);
      expect(r[0].width, closeTo((screen.width - 4) * 2 / 3, 0.01));
      expect(r[1].left, r[2].left);
      expect(r[2].top, greaterThan(r[1].bottom));
    });

    test('a short last row is centred, and no tile leaves the screen', () {
      for (var n = 2; n <= 12; n++) {
        for (final f in [false, true]) {
          final r = multiViewLayout(screen, n, featured: f);
          expect(r, hasLength(n));
          for (final t in r) {
            expect(t.left, greaterThanOrEqualTo(-0.01));
            expect(t.top, greaterThanOrEqualTo(-0.01));
            expect(t.right, lessThanOrEqualTo(screen.width + 0.01));
            expect(t.bottom, lessThanOrEqualTo(screen.height + 0.01));
          }
        }
      }
      final five = multiViewLayout(screen, 5, featured: false);
      // 3 + 2: the bottom pair is centred under the top row.
      final mid = (five[3].left + five[4].right) / 2;
      expect(mid, closeTo(screen.width / 2, 0.01));
    });
  });

  group('multiViewNeighbour', () {
    test('2×2 moves to the tile beside, never diagonally', () {
      final r = multiViewLayout(screen, 4, featured: false);
      expect(multiViewNeighbour(r, 0, right), 1);
      expect(multiViewNeighbour(r, 0, down), 2);
      expect(multiViewNeighbour(r, 3, up), 1);
      expect(multiViewNeighbour(r, 3, left), 2);
      expect(multiViewNeighbour(r, 0, left), isNull);
      expect(multiViewNeighbour(r, 0, up), isNull);
    });

    test('one big + three: the stack is walked one tile at a time', () {
      final r = multiViewLayout(screen, 4, featured: true);
      // From the top small tile, Down reaches the middle one (it skipped
      // straight to the bottom before).
      expect(multiViewNeighbour(r, 1, down), 2);
      expect(multiViewNeighbour(r, 2, down), 3);
      expect(multiViewNeighbour(r, 3, up), 2);
      // Left from any small tile goes to the big one.
      for (final i in [1, 2, 3]) {
        expect(multiViewNeighbour(r, i, left), 0);
      }
      expect(multiViewNeighbour(r, 0, right), isNotNull);
    });
  });
}
