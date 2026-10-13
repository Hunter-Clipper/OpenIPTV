import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/core/models/programme.dart';
import 'package:open_iptv/features/live_tv/tv_guide_screen.dart';

void main() {
  final day = DateTime(2026, 1, 1);
  Programme p(String title, int fromMin, int toMin) => Programme(
        channelId: 'c',
        start: day.add(Duration(minutes: fromMin)),
        end: day.add(Duration(minutes: toMin)),
        title: title,
      );
  List<String> titles(List<Programme> list) => [for (final x in list) x.title];

  test('two mixed schedules: the one already showing wins', () {
    // Like BET Her HD on 2026-10-13: 12:00–12:30 and 12:12–12:48.
    final row = guideRow([
      p('b', 12, 48),
      p('a', 0, 30),
      p('c', 30, 60),
      p('d', 48, 84),
      p('e', 84, 120),
    ]);
    expect(titles(row), ['a', 'c', 'e']);
  });

  test('a couple of minutes of overlap is kept', () {
    expect(titles(guideRow([p('a', 0, 31), p('b', 30, 60)])), ['a', 'b']);
  });

  test('back-to-back programmes are untouched', () {
    expect(titles(guideRow([p('a', 0, 30), p('b', 30, 60), p('c', 60, 90)])),
        ['a', 'b', 'c']);
  });
}
