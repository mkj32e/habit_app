import 'package:flutter_test/flutter_test.dart';
import 'package:habit_app/core/dates.dart';
import 'package:habit_app/data/repository.dart';
import 'package:habit_app/logic/gamification.dart';
import 'package:habit_app/logic/messages.dart';
import 'package:habit_app/logic/stats.dart';
import 'package:habit_app/models/habit.dart';

void main() {
  // A fixed "today": Wednesday 2026-10-14.
  final t = DateTime(2026, 10, 14);
  DateTime ago(int n) => addDays(t, -n);

  Habit daily({int createdDaysAgo = 30, int target = 1}) =>
      Habit(name: 'Lire', createdAt: ago(createdDaysAgo), target: target);

  void doneOn(Habit h, Iterable<int> daysAgo) {
    for (final n in daysAgo) {
      HabitOps.setDone(h, ago(n), true);
    }
  }

  group('streaks', () {
    test('today not done yet does not break the streak', () {
      final h = daily();
      doneOn(h, [1, 2, 3]);
      final s = computeStats(h, t);
      expect(s.currentStreak, 3);
      expect(s.missedYesterday, isFalse);
    });

    test('today done extends the streak', () {
      final h = daily();
      doneOn(h, [0, 1, 2, 3]);
      expect(computeStats(h, t).currentStreak, 4);
    });

    test('a missed day resets the current streak but keeps the record', () {
      final h = daily();
      doneOn(h, [1, 2, 4, 5, 6, 7, 8]);
      final s = computeStats(h, t);
      expect(s.currentStreak, 2);
      expect(s.bestStreak, 5);
    });

    test('missed yesterday is flagged (never miss twice)', () {
      final h = daily();
      doneOn(h, [2, 3]);
      expect(computeStats(h, t).missedYesterday, isTrue);
    });

    test('a streak freeze bridges a missed day', () {
      final h = daily();
      doneOn(h, [1, 3, 4]);
      h.frozenDays.add(dayKey(ago(2)));
      expect(computeStats(h, t).currentStreak, 4);
    });

    test('unscheduled days are skipped for fixed weekdays', () {
      // Mon/Wed/Fri only. Today is Wednesday.
      final h = Habit(name: 'Sport', createdAt: ago(30), frequency: FrequencyType.weekdays, weekdays: {1, 3, 5});
      doneOn(h, [0, 2, 5, 7]); // Wed, Mon, Fri(prev), Wed(prev)
      expect(computeStats(h, t).currentStreak, 4);
      expect(isScheduledOn(h, ago(1)), isFalse); // Tuesday
    });

    test('counter habits need the full target', () {
      final h = daily(target: 3);
      HabitOps.increment(h, t);
      HabitOps.increment(h, t);
      expect(isDoneOn(h, t), isFalse);
      expect(HabitOps.increment(h, t), isTrue); // became done
      expect(isDoneOn(h, t), isTrue);
      expect(countOn(h, t), 3);
      HabitOps.increment(h, t); // clamped
      expect(countOn(h, t), 3);
    });

    test('mini version counts as done', () {
      final h = daily();
      HabitOps.markMini(h, ago(1));
      HabitOps.markMini(h, ago(2));
      expect(computeStats(h, t).currentStreak, 2);
      HabitOps.setDone(h, ago(1), false);
      expect(h.miniDays.contains(dayKey(ago(1))), isFalse);
    });
  });

  group('per week habits', () {
    test('weekly streak counts weeks meeting the goal', () {
      final h = Habit(name: 'Course', createdAt: ago(40), frequency: FrequencyType.perWeek, perWeek: 2);
      // Previous 3 full weeks: 2 sessions each. Today is Wed; this week's Monday = ago(2).
      doneOn(h, [4, 6, 11, 13, 18, 20]);
      final s = computeStats(h, t);
      expect(s.inWeeks, isTrue);
      expect(s.currentStreak, 3);
    });

    test('due today until the weekly goal is met', () {
      final h = Habit(name: 'Course', createdAt: ago(40), frequency: FrequencyType.perWeek, perWeek: 2);
      expect(isDueToday(h, t), isTrue);
      doneOn(h, [1, 2]); // Tue + Mon this week
      expect(isDueToday(h, t), isFalse);
    });
  });

  group('gamification', () {
    test('levels', () {
      expect(levelFor(0).number, 1);
      expect(levelFor(99).number, 1);
      expect(levelFor(100).number, 2);
      expect(levelFor(300).number, 3); // 100 + 200
      expect(levelFor(150).xpInLevel, 50);
    });

    test('perfect days and freezes', () {
      final a = daily(createdDaysAgo: 10);
      final b = daily(createdDaysAgo: 10);
      doneOn(a, List.generate(8, (i) => i + 1));
      doneOn(b, List.generate(8, (i) => i + 1));
      final g = computeGlobal([a, b], t);
      expect(g.perfectDays, 8);
      expect(g.freezesAvailable, 2); // 1 starting + 1 for 7 perfect days
      expect(g.todayTotal, 2);
      expect(g.todayDone, 0);
    });
  });

  test('message placeholders are filled', () {
    final h = daily()
      ..emoji = '📚'
      ..why = 'apprendre chaque jour'
      ..miniVersion = 'une page';
    doneOn(h, [1, 2]);
    final msg = renderMessage('{emoji} {habitude} · série {serie} · {pourquoi} · {mini} · {prenom}', h,
        stats: computeStats(h, t), userName: 'Tom');
    expect(msg, '📚 Lire · série 2 · apprendre chaque jour · une page · Tom');
  });

  test('habit json round trip', () {
    final h = daily(target: 4)
      ..unit = 'pages'
      ..reminders = [Reminder(hour: 7, minute: 30, nag: true, nagMessages: ['Allez !'])];
    doneOn(h, [1]);
    final back = Habit.fromJson(h.toJson());
    expect(back.name, h.name);
    expect(back.reminders.single.nagMessages, ['Allez !']);
    expect(back.reminders.single.minute, 30);
    expect(back.log, h.log);
  });
}
