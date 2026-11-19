import 'package:flutter_test/flutter_test.dart';
import 'package:open_iptv/features/sports/sports_reminders.dart';

void main() {
  final now = DateTime.utc(2026, 11, 19, 20, 0);
  ReminderGame g(String id, Duration fromNow) => ReminderGame(
      id: id,
      title: 'A at B',
      league: 'L',
      kickoff: now.add(fromNow));

  test('only games kicking off within the lead are due', () {
    final due = dueReminders([
      g('soon', const Duration(minutes: 10)),
      g('edge', const Duration(minutes: 20)),
      g('later', const Duration(minutes: 21)),
      g('started', const Duration(minutes: -1)),
    ], now, {});
    expect(due.map((d) => d.id), ['soon', 'edge']);
  });

  test('an announced game is not announced again', () {
    final due = dueReminders(
        [g('a', const Duration(minutes: 5))], now, {'a'});
    expect(due, isEmpty);
  });

  test('round-trips through json', () {
    final x = g('a', const Duration(minutes: 5));
    final y = ReminderGame.fromJson(x.toJson());
    expect(y.id, x.id);
    expect(y.kickoff, x.kickoff);
  });
}
