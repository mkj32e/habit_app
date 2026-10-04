import 'dart:math';

import '../core/dates.dart';
import '../models/habit.dart';
import 'stats.dart';

class Level {
  const Level(this.number, this.title, this.xpInLevel, this.xpForNext);
  final int number;
  final String title;
  final int xpInLevel;
  final int xpForNext;
  double get progress => xpForNext == 0 ? 1 : xpInLevel / xpForNext;
}

const _levelTitles = [
  'Graine',
  'Pousse',
  'Apprenti',
  'Régulier',
  'Constant',
  'Discipliné',
  'Inarrêtable',
  'Maître du rituel',
  'Légende',
];

/// Level n -> n+1 costs 100 * n XP.
Level levelFor(int xp) {
  var n = 1;
  var remaining = xp;
  while (remaining >= 100 * n) {
    remaining -= 100 * n;
    n++;
  }
  final title = _levelTitles[min((n - 1) ~/ 2, _levelTitles.length - 1)];
  return Level(n, title, remaining, 100 * n);
}

class GlobalStats {
  GlobalStats({
    required this.perHabit,
    required this.xp,
    required this.perfectDays,
    required this.perfectStreak,
    required this.totalCompletions,
    required this.bestStreak,
    required this.freezesAvailable,
    required this.freezesUsed,
    required this.habitCount,
    required this.todayDone,
    required this.todayTotal,
    required this.avgScore,
    required this.miniCount,
  });

  final Map<String, HabitStats> perHabit;
  final int xp;
  final int perfectDays;

  /// Consecutive perfect days ending yesterday/today.
  final int perfectStreak;
  final int totalCompletions;
  final int bestStreak;
  final int freezesAvailable;
  final int freezesUsed;
  final int habitCount;
  final int todayDone;
  final int todayTotal;
  final double avgScore;
  final int miniCount;

  Level get level => levelFor(xp);
}

/// A day is perfect when every habit scheduled that day was done (at least one).
bool isPerfectDay(List<Habit> habits, DateTime d) {
  var any = false;
  for (final h in habits) {
    if (h.archived || d.isBefore(dateOnly(h.createdAt))) continue;
    if (h.frequency == FrequencyType.perWeek) continue;
    if (!isScheduledOn(h, d)) continue;
    any = true;
    if (!isCoveredOn(h, d)) return false;
  }
  return any;
}

GlobalStats computeGlobal(List<Habit> habits, [DateTime? now]) {
  final t = now == null ? today() : dateOnly(now);
  final active = habits.where((h) => !h.archived).toList();
  final per = <String, HabitStats>{};
  var xp = 0, total = 0, best = 0, used = 0, mini = 0;
  var scoreSum = 0.0;
  DateTime? earliest;
  for (final h in habits) {
    final s = computeStats(h, t);
    per[h.id] = s;
    xp += s.xp;
    total += s.total;
    best = max(best, s.bestStreak);
    used += h.frozenDays.length;
    mini += h.miniDays.length;
    if (!h.archived) scoreSum += s.score;
    final c = dateOnly(h.createdAt);
    if (earliest == null || c.isBefore(earliest)) earliest = c;
  }

  var perfect = 0, perfectStreak = 0, running = 0;
  if (earliest != null) {
    for (var d = earliest; !d.isAfter(t); d = addDays(d, 1)) {
      if (isPerfectDay(active, d)) {
        perfect++;
        running++;
        xp += 25;
      } else if (d != t) {
        running = 0;
      }
    }
    perfectStreak = running;
  }

  final due = active.where((h) => isDueToday(h, t)).toList();
  final doneToday = due.where((h) => isDoneOn(h, t)).length;

  // One freeze to start, +1 for every 7 perfect days.
  final earned = 1 + perfect ~/ 7;

  return GlobalStats(
    perHabit: per,
    xp: xp,
    perfectDays: perfect,
    perfectStreak: perfectStreak,
    totalCompletions: total,
    bestStreak: best,
    freezesAvailable: max(0, earned - used),
    freezesUsed: used,
    habitCount: active.length,
    todayDone: doneToday,
    todayTotal: due.length,
    avgScore: active.isEmpty ? 0 : scoreSum / active.length,
    miniCount: mini,
  );
}

class Achievement {
  const Achievement(this.id, this.emoji, this.title, this.description, this.unlocked);
  final String id;
  final String emoji;
  final String title;
  final String description;
  final bool Function(GlobalStats g, BadgeContext c) unlocked;
}

class BadgeContext {
  const BadgeContext({this.friends = 0, this.challenges = 0});
  final int friends;
  final int challenges;
}

final List<Achievement> kBadges = [
  Achievement('first', '🌱', 'Premier pas', 'Valider une habitude pour la première fois',
      (g, _) => g.totalCompletions >= 1),
  Achievement('three_habits', '🧩', 'Architecte', 'Avoir 3 habitudes actives', (g, _) => g.habitCount >= 3),
  Achievement('streak3', '🔥', 'Ça chauffe', 'Série de 3 jours', (g, _) => g.bestStreak >= 3),
  Achievement('streak7', '⚡', 'Une semaine pile', 'Série de 7 jours', (g, _) => g.bestStreak >= 7),
  Achievement('streak21', '🧠', 'Câblé', 'Série de 21 jours', (g, _) => g.bestStreak >= 21),
  Achievement('streak66', '🏔️', 'Automatisme', 'Série de 66 jours — le temps moyen pour ancrer une habitude',
      (g, _) => g.bestStreak >= 66),
  Achievement('streak100', '💯', 'Centurion', 'Série de 100 jours', (g, _) => g.bestStreak >= 100),
  Achievement('perfect1', '⭐', 'Journée parfaite', 'Tout valider en une journée', (g, _) => g.perfectDays >= 1),
  Achievement('perfect7', '🌟', 'Semaine parfaite', '7 journées parfaites d\'affilée',
      (g, _) => g.perfectStreak >= 7),
  Achievement('total50', '🎯', 'Cinquantaine', '50 validations au total', (g, _) => g.totalCompletions >= 50),
  Achievement('total250', '🏆', 'Machine', '250 validations au total', (g, _) => g.totalCompletions >= 250),
  Achievement('mini', '🤏', 'Règle des 2 minutes', 'Valider avec la version mini plutôt que rien',
      (g, _) => g.miniCount >= 1),
  Achievement('freeze', '🧊', 'Filet de sécurité', 'Utiliser un gel de série', (g, _) => g.freezesUsed >= 1),
  Achievement('level5', '🚀', 'Niveau 5', 'Atteindre le niveau 5', (g, _) => g.level.number >= 5),
  Achievement('level10', '👑', 'Niveau 10', 'Atteindre le niveau 10', (g, _) => g.level.number >= 10),
  Achievement('friend', '🤝', 'Pas seul', 'Ajouter un ami', (_, c) => c.friends >= 1),
  Achievement('challenge', '⚔️', 'Défi lancé', 'Rejoindre un défi multijoueur', (_, c) => c.challenges >= 1),
];
