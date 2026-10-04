import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../logic/gamification.dart';
import '../logic/stats.dart';
import '../models/app_settings.dart';
import '../models/habit.dart';
import '../services/notification_service.dart';
import '../services/social_service.dart';
import '../services/widget_service.dart';
import 'repository.dart';

class CompletionResult {
  CompletionResult({this.becameDone = false, this.perfectDay = false, this.newBadges = const []});
  final bool becameDone;
  final bool perfectDay;
  final List<Achievement> newBadges;
}

/// UI-facing state. All mutations persist, refresh reminders, the home screen
/// widget and (debounced) the multiplayer stats.
class HabitStore extends ChangeNotifier {
  HabitStore(this.social);

  final SocialService social;
  AppData data = AppData();
  bool loaded = false;
  GlobalStats? _global;
  Timer? _syncTimer;
  DateTime? _scheduledDay;

  AppSettings get settings => data.settings;

  List<Habit> get habits => data.habits.where((h) => !h.archived).toList()..sort((a, b) => a.order.compareTo(b.order));

  List<Habit> get archivedHabits => data.habits.where((h) => h.archived).toList();

  GlobalStats get global => _global ??= computeGlobal(data.habits);

  HabitStats stats(Habit h) => global.perHabit[h.id] ?? computeStats(h);

  Habit? byId(String id) => data.habit(id);

  List<Habit> get dueToday {
    final t = today();
    return habits.where((h) => isDueToday(h, t)).toList();
  }

  BadgeContext get badgeContext =>
      BadgeContext(friends: social.friends.length, challenges: social.challenges.length);

  Future<void> load() async {
    data = await Repository.load();
    loaded = true;
    _global = null;
    notifyListeners();
    unawaited(_afterStartup());
  }

  Future<void> _afterStartup() async {
    _scheduledDay = today();
    await NotificationService.rescheduleAll(data);
    await Repository.save(data);
    await WidgetService.update(data);
    _scheduleSync();
  }

  /// Background isolates (widget, notification actions) may have changed the file.
  /// Reminders are rebuilt only if something changed or the day rolled over.
  Future<void> reloadFromDisk() async {
    final fresh = await Repository.load();
    final changed = jsonEncode(fresh.toJson()) != jsonEncode(data.toJson());
    data = fresh;
    _global = null;
    notifyListeners();
    if (changed || _scheduledDay != today()) unawaited(_afterStartup());
  }

  Future<void> _commit({Habit? dayChanged, DateTime? day, String? rescheduleHabitId, bool rescheduleAll = false}) async {
    _global = null;
    notifyListeners();
    if (dayChanged != null) {
      await NotificationService.onHabitDayChanged(data, dayChanged, day ?? today());
    }
    if (rescheduleHabitId != null) await NotificationService.rescheduleHabit(data, rescheduleHabitId);
    if (rescheduleAll) await NotificationService.rescheduleAll(data);
    await Repository.save(data);
    await WidgetService.update(data);
    _scheduleSync();
  }

  void _scheduleSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(seconds: 4), () => social.syncStats(data));
  }

  // ------------------------------------------------------------ completions

  Future<CompletionResult> toggle(Habit h, [DateTime? day]) async {
    final d = day ?? today();
    if (isDoneOn(h, d)) {
      HabitOps.setDone(h, d, false);
      await _commit(dayChanged: h, day: d);
      return CompletionResult();
    }
    HabitOps.setDone(h, d, true);
    return _afterCompletion(h, d, true);
  }

  Future<CompletionResult> increment(Habit h, {int by = 1, DateTime? day}) async {
    final d = day ?? today();
    final became = HabitOps.increment(h, d, by: by);
    if (!became) {
      await _commit(dayChanged: h, day: d);
      return CompletionResult();
    }
    return _afterCompletion(h, d, true);
  }

  Future<CompletionResult> markMini(Habit h, [DateTime? day]) async {
    final d = day ?? today();
    HabitOps.markMini(h, d);
    return _afterCompletion(h, d, true);
  }

  Future<CompletionResult> _afterCompletion(Habit h, DateTime d, bool became) async {
    final perfect = became && d == today() && isPerfectDay(habits, d);
    await _commit(dayChanged: h, day: d);
    return CompletionResult(becameDone: became, perfectDay: perfect, newBadges: collectNewBadges());
  }

  bool useFreeze(Habit h, DateTime day) {
    if (global.freezesAvailable <= 0) return false;
    h.frozenDays.add(dayKey(day));
    unawaited(_commit());
    return true;
  }

  /// Badges unlocked since last check (and marks them as seen).
  List<Achievement> collectNewBadges() {
    final g = global;
    final ctx = badgeContext;
    final fresh = <Achievement>[];
    for (final b in kBadges) {
      if (!settings.seenBadges.contains(b.id) && b.unlocked(g, ctx)) {
        settings.seenBadges.add(b.id);
        fresh.add(b);
      }
    }
    return fresh;
  }

  Future<void> handleNotifAction(NotifAction a) async {
    final h = byId(a.habitId);
    if (h == null) return;
    switch (a.action) {
      case 'done':
        if (!isDoneOn(h, a.day)) await toggle(h, a.day);
      case 'inc':
        await increment(h, day: a.day);
      case 'mini':
        await markMini(h, a.day);
      case 'snooze':
        await NotificationService.snooze(data, h, a.reminderId);
        await Repository.save(data);
    }
  }

  // ----------------------------------------------------------------- CRUD

  Future<void> addHabit(Habit h) async {
    h.order = data.habits.isEmpty ? 0 : data.habits.map((e) => e.order).reduce((a, b) => a > b ? a : b) + 1;
    data.habits.add(h);
    await _commit(rescheduleHabitId: h.id);
  }

  Future<void> updateHabit(Habit edited) async {
    final i = data.habits.indexWhere((h) => h.id == edited.id);
    if (i < 0) return;
    data.habits[i] = edited;
    await _commit(rescheduleHabitId: edited.id);
  }

  Future<void> deleteHabit(Habit h) async {
    data.habits.removeWhere((e) => e.id == h.id);
    await _commit(rescheduleHabitId: h.id);
  }

  Future<void> setArchived(Habit h, bool archived) async {
    h.archived = archived;
    await _commit(rescheduleHabitId: h.id);
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = habits;
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    for (var i = 0; i < list.length; i++) {
      list[i].order = i;
    }
    await _commit();
  }

  Future<void> updateSettings(void Function(AppSettings s) change, {bool reschedule = false}) async {
    change(settings);
    await _commit(rescheduleAll: reschedule);
  }

  Future<String> exportJson() => Repository.exportJson(data);

  Future<void> importJson(String raw) async {
    final imported = Repository.importJson(raw);
    // Keep the old ids so rescheduleAll cancels them.
    imported.scheduled
      ..clear()
      ..addAll(data.scheduled);
    data = imported;
    await _commit(rescheduleAll: true);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}
