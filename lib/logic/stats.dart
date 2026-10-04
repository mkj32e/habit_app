import 'dart:math';

import '../core/dates.dart';
import '../models/habit.dart';

bool isScheduledOn(Habit h, DateTime day) {
  switch (h.frequency) {
    case FrequencyType.daily:
    case FrequencyType.perWeek:
      return true;
    case FrequencyType.weekdays:
      return h.weekdays.contains(day.weekday);
  }
}

bool isDoneOn(Habit h, DateTime day) {
  final k = dayKey(day);
  return (h.log[k] ?? 0) >= h.target || h.miniDays.contains(k);
}

/// Done, or protected by a streak freeze.
bool isCoveredOn(Habit h, DateTime day) => isDoneOn(h, day) || h.frozenDays.contains(dayKey(day));

int countOn(Habit h, DateTime day) => h.log[dayKey(day)] ?? 0;

/// Number of covered days in the week (Mon-Sun) containing [day].
int weekCount(Habit h, DateTime day) {
  final start = weekStart(day);
  var c = 0;
  for (var i = 0; i < 7; i++) {
    if (isCoveredOn(h, addDays(start, i))) c++;
  }
  return c;
}

/// Whether the habit should appear in today's list.
bool isDueToday(Habit h, [DateTime? now]) {
  final t = now == null ? today() : dateOnly(now);
  if (h.archived) return false;
  if (h.frequency == FrequencyType.perWeek) {
    return isDoneOn(h, t) || weekCount(h, t) < h.perWeek;
  }
  return isScheduledOn(h, t);
}

class HabitStats {
  const HabitStats({
    required this.currentStreak,
    required this.bestStreak,
    required this.total,
    required this.score,
    required this.rate30,
    required this.inWeeks,
    required this.missedYesterday,
    required this.xp,
  });

  final int currentStreak;
  final int bestStreak;
  final int total;

  /// Habit strength 0..1 (exponential moving average, forgiving with a single miss).
  final double score;

  /// Completion rate over the last 30 days 0..1.
  final double rate30;

  /// Streaks are counted in weeks for "N times per week" habits.
  final bool inWeeks;

  /// Scheduled yesterday, not done and not frozen ("never miss twice").
  final bool missedYesterday;
  final int xp;

  String get streakUnit => inWeeks ? 'sem.' : (currentStreak > 1 ? 'jours' : 'jour');

  static const empty = HabitStats(
    currentStreak: 0,
    bestStreak: 0,
    total: 0,
    score: 0,
    rate30: 0,
    inWeeks: false,
    missedYesterday: false,
    xp: 0,
  );
}

const _alpha = 0.07;

HabitStats computeStats(Habit h, [DateTime? now]) {
  final t = now == null ? today() : dateOnly(now);
  final created = dateOnly(h.createdAt);
  final start = _firstRelevantDay(h, created);
  final total = h.log.entries.where((e) => e.value >= h.target).length;

  if (h.frequency == FrequencyType.perWeek) return _weeklyStats(h, start, t, total);

  var running = 0, best = 0;
  var score = 0.0;
  var xp = 0;
  final lastDay = isCoveredOn(h, t) ? t : addDays(t, -1);
  for (var d = start; !d.isAfter(lastDay); d = addDays(d, 1)) {
    if (!isScheduledOn(h, d)) continue;
    final covered = isCoveredOn(h, d);
    if (covered) {
      running++;
      best = max(best, running);
      if (isDoneOn(h, d)) {
        xp += h.miniDays.contains(dayKey(d)) ? 5 : 10;
        if (running % 7 == 0) xp += 50; // streak milestone bonus
      }
    } else {
      running = 0;
    }
    score += _alpha * ((covered ? 1.0 : 0.0) - score);
  }

  // Rate over the last 30 days (only days since creation).
  var sched = 0, done = 0;
  for (var i = 0; i < 30; i++) {
    final d = addDays(t, -i);
    if (d.isBefore(start)) break;
    if (!isScheduledOn(h, d)) continue;
    if (d == t && !isCoveredOn(h, d)) continue; // today isn't over
    sched++;
    if (isCoveredOn(h, d)) done++;
  }

  final y = addDays(t, -1);
  final missedYesterday = !y.isBefore(start) && isScheduledOn(h, y) && !isCoveredOn(h, y);

  return HabitStats(
    currentStreak: running,
    bestStreak: best,
    total: total,
    score: score.clamp(0, 1),
    rate30: sched == 0 ? 0 : done / sched,
    inWeeks: false,
    missedYesterday: missedYesterday,
    xp: xp,
  );
}

/// Earliest day we consider: creation day, or earlier if the user logged past days.
DateTime _firstRelevantDay(Habit h, DateTime created) {
  var first = created;
  for (final k in h.log.keys) {
    final d = parseDayKey(k);
    if (d.isBefore(first)) first = d;
  }
  return first;
}

HabitStats _weeklyStats(Habit h, DateTime start, DateTime t, int total) {
  final firstWeek = weekStart(start);
  final thisWeek = weekStart(t);
  var running = 0, best = 0, xp = 0;
  var score = 0.0;
  for (var w = firstWeek; !w.isAfter(thisWeek); w = addDays(w, 7)) {
    final count = weekCount(h, w);
    // The creation week only requires what was still possible.
    var need = h.perWeek;
    if (w == firstWeek) need = min(need, 7 - daysBetween(w, start));
    final met = count >= need;
    final isCurrent = w == thisWeek;
    for (var i = 0; i < 7; i++) {
      final d = addDays(w, i);
      if (isDoneOn(h, d)) xp += h.miniDays.contains(dayKey(d)) ? 5 : 10;
    }
    if (isCurrent && !met) break; // current week still in progress
    if (met) {
      running++;
      best = max(best, running);
      if (running % 4 == 0) xp += 50;
    } else {
      running = 0;
    }
    score += 0.25 * (min(1.0, count / max(1, need)) - score);
  }

  var done = 0;
  for (var i = 0; i < 28; i++) {
    final d = addDays(t, -i);
    if (d.isBefore(start)) break;
    if (isCoveredOn(h, d)) done++;
  }
  final weeks = min(4, (daysBetween(start, t) ~/ 7) + 1);
  return HabitStats(
    currentStreak: running,
    bestStreak: best,
    total: total,
    score: score.clamp(0, 1),
    rate30: min(1, done / (h.perWeek * weeks)),
    inWeeks: true,
    missedYesterday: false,
    xp: xp,
  );
}

/// Last [n] days as a compact string, '1' done, '0' missed, '-' not scheduled.
String lastDaysPattern(Habit h, int n, [DateTime? now]) {
  final t = now == null ? today() : dateOnly(now);
  final b = StringBuffer();
  for (var i = n - 1; i >= 0; i--) {
    final d = addDays(t, -i);
    if (!isScheduledOn(h, d) || d.isBefore(dateOnly(h.createdAt))) {
      b.write(isDoneOn(h, d) ? '1' : '-');
    } else {
      b.write(isCoveredOn(h, d) ? '1' : '0');
    }
  }
  return b.toString();
}
