import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../core/dates.dart';
import '../data/repository.dart';
import '../logic/gamification.dart';
import '../logic/messages.dart';
import '../logic/stats.dart';
import '../models/habit.dart';

/// Pushes today's state to the Android home screen widgets.
class WidgetService {
  static const todayProvider = 'com.rituel.habit_app.TodayWidgetProvider';
  static const progressProvider = 'com.rituel.habit_app.ProgressWidgetProvider';

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static Future<void> update(AppData data) async {
    if (!supported) return;
    try {
      final t = today();
      final g = computeGlobal(data.habits, t);
      final due = data.habits.where((h) => isDueToday(h, t)).toList()
        ..sort((a, b) {
          final da = isDoneOn(a, t) ? 1 : 0, db = isDoneOn(b, t) ? 1 : 0;
          if (da != db) return da.compareTo(db);
          return _nextTime(a).compareTo(_nextTime(b));
        });

      final items = due.map((h) {
        final s = g.perHabit[h.id] ?? HabitStats.empty;
        return {
          'id': h.id,
          'name': h.name,
          'emoji': h.emoji,
          'color': h.color,
          'done': isDoneOn(h, t),
          'count': countOn(h, t),
          'target': h.target,
          'unit': h.unit,
          'streak': s.currentStreak,
          'streakUnit': s.inWeeks ? 'sem' : 'j',
          'time': _nextTimeLabel(h),
        };
      }).toList();

      var topStreak = 0;
      for (final s in g.perHabit.values) {
        if (s.currentStreak > topStreak) topStreak = s.currentStreak;
      }
      final level = g.level;
      final principle = principleOfTheDay();

      await HomeWidget.saveWidgetData<String>('today_items', jsonEncode(items));
      await HomeWidget.saveWidgetData<int>('today_done', g.todayDone);
      await HomeWidget.saveWidgetData<int>('today_total', g.todayTotal);
      await HomeWidget.saveWidgetData<String>('today_date', prettyDate(t));
      await HomeWidget.saveWidgetData<String>('today_key', dayKey(t));
      await HomeWidget.saveWidgetData<int>('top_streak', topStreak);
      await HomeWidget.saveWidgetData<int>('perfect_streak', g.perfectStreak);
      await HomeWidget.saveWidgetData<String>('level_label', 'Niv. ${level.number} · ${level.title}');
      await HomeWidget.saveWidgetData<int>('level_progress', (level.progress * 100).round());
      await HomeWidget.saveWidgetData<String>('principle', principle.$1);
      await HomeWidget.saveWidgetData<int>('accent', data.settings.accent);
      await HomeWidget.updateWidget(qualifiedAndroidName: todayProvider);
      await HomeWidget.updateWidget(qualifiedAndroidName: progressProvider);
    } catch (e) {
      debugPrint('widget update failed: $e');
    }
  }

  static int _nextTime(Habit h) {
    final times = h.reminders.where((r) => r.enabled).map((r) => r.hour * 60 + r.minute).toList()..sort();
    return times.isEmpty ? 24 * 60 : times.first;
  }

  static String _nextTimeLabel(Habit h) {
    final m = _nextTime(h);
    if (m >= 24 * 60) return '';
    return hm(m ~/ 60, m % 60);
  }

  static Future<bool> canPin() async {
    if (!supported) return false;
    return await HomeWidget.isRequestPinWidgetSupported() ?? false;
  }

  static Future<void> requestPin({bool progress = false}) async {
    if (!supported) return;
    await HomeWidget.requestPinWidget(qualifiedAndroidName: progress ? progressProvider : todayProvider);
  }
}
