import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/dates.dart';
import '../data/repository.dart';
import '../logic/messages.dart';
import '../logic/stats.dart';
import '../models/app_settings.dart';
import '../models/habit.dart';
import 'background.dart';

/// A notification action decoded from Android or Windows.
class NotifAction {
  NotifAction(this.action, this.habitId, this.day, this.reminderId);
  final String action; // open | done | inc | mini | snooze
  final String habitId;
  final DateTime day;
  final String reminderId;

  static NotifAction? parse(NotificationResponse r) {
    // Windows sends the button arguments in actionId/payload ("act:<action>|...").
    var raw = r.actionId ?? '';
    String action;
    String payload;
    if (raw.startsWith('act:')) {
      raw = raw.substring(4);
      final i = raw.indexOf('|');
      if (i < 0) return null;
      action = raw.substring(0, i);
      payload = raw.substring(i + 1);
    } else {
      action = (r.actionId == null || r.actionId!.isEmpty || r.actionId == r.payload) ? 'open' : r.actionId!;
      payload = r.payload ?? '';
    }
    final p = payload.split('|');
    if (p.length < 2) return null;
    return NotifAction(action, p[0], parseDayKey(p[1]), p.length > 2 ? p[2] : '');
  }
}

class _Planned {
  _Planned(this.habit, this.reminder, this.day, this.time, this.title, this.body, this.nagIndex);
  final Habit habit;
  final Reminder reminder;
  final DateTime day;
  final DateTime time;
  final String title;
  final String body;
  final int nagIndex; // 0 = main reminder
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Set by the UI layer to handle taps/actions while the app is running.
  static Future<void> Function(NotifAction a)? foregroundHandler;

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  static const _maxScheduled = 380; // Android caps alarms at ~500 per app.
  static const _daysAhead = 7;
  static const _nagDaysAhead = 2;

  static Future<void> init({bool background = false}) async {
    if (_ready || !supported) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Fallback: UTC offset match.
      final offset = DateTime.now().timeZoneOffset;
      final match = tz.timeZoneDatabase.locations.values.firstWhere(
        (l) => l.currentTimeZone.offset == offset,
        orElse: () => tz.UTC,
      );
      tz.setLocalLocation(match);
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_stat_rituel'),
      windows: WindowsInitializationSettings(
        appName: 'Rituel',
        appUserModelId: 'Rituel.HabitTracker',
        guid: '6c1f7a52-8d3b-4e8e-9a41-2b7d5e3c9f10',
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: background ? null : _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    _ready = true;

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'rituel_reminders',
        'Rappels',
        description: 'Rappels de tes habitudes',
        importance: Importance.high,
      ));
      await android?.createNotificationChannel(AndroidNotificationChannel(
        'rituel_nags',
        'Relances insistantes',
        description: 'Relances répétées jusqu\'à ce que l\'habitude soit faite',
        importance: Importance.max,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 300, 150, 300, 150, 600]),
      ));
    }
  }

  /// Handles a tap that cold-started the app.
  static Future<void> handleLaunchDetails() async {
    if (!supported) return;
    final d = await _plugin.getNotificationAppLaunchDetails();
    final r = d?.notificationResponse;
    if (d?.didNotificationLaunchApp == true && r != null) await _onForegroundResponse(r);
  }

  static Future<void> _onForegroundResponse(NotificationResponse r) async {
    final a = NotifAction.parse(r);
    if (a == null) return;
    final h = foregroundHandler;
    if (h != null) {
      await h(a);
    } else {
      await BackgroundActions.handle(a);
    }
  }

  static Future<bool> requestPermissions() async {
    if (!supported) return false;
    await init();
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ok = await android?.requestNotificationsPermission() ?? false;
      if (await android?.canScheduleExactNotifications() == false) {
        await android?.requestExactAlarmsPermission();
      }
      return ok;
    }
    return true;
  }

  static Future<AndroidScheduleMode> _scheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    return exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  // ---------------------------------------------------------------- planning

  static List<_Planned> _plan(Habit h, AppSettings s, DateTime now) {
    final out = <_Planned>[];
    if (h.archived) return out;
    final t0 = dateOnly(now);
    final stats = computeStats(h, now);
    for (var offset = 0; offset < _daysAhead; offset++) {
      final day = addDays(t0, offset);
      if (!isScheduledOn(h, day) || isDoneOn(h, day)) continue;
      if (h.frequency == FrequencyType.perWeek && weekCount(h, day) >= h.perWeek) continue;
      for (final r in h.reminders) {
        if (!r.enabled) continue;
        final at = DateTime(day.year, day.month, day.day, r.hour, r.minute);
        final done = countOn(h, day);
        if (at.isAfter(now)) {
          out.add(_Planned(
            h,
            r,
            day,
            at,
            renderMessage(r.title, h, stats: stats, userName: s.userName, done: done),
            renderMessage(r.body, h, stats: stats, userName: s.userName, done: done),
            0,
          ));
        }
        if (!r.nag || offset >= _nagDaysAhead) continue;
        final msgs = r.nagMessages.where((m) => m.trim().isNotEmpty).toList();
        final pool = msgs.isNotEmpty ? msgs : s.defaultNagMessages;
        for (var k = 1; k <= r.nagMaxCount; k++) {
          final tk = at.add(Duration(minutes: r.nagIntervalMinutes * k));
          if (tk.day != day.day || tk.hour >= s.nagStopHour || tk.hour < s.nagStartHour) break;
          if (!tk.isAfter(now)) continue;
          final template = pool.isEmpty ? r.body : pool[(k - 1) % pool.length];
          out.add(_Planned(
            h,
            r,
            day,
            tk,
            renderMessage(r.title, h, stats: stats, userName: s.userName, n: k + 1, done: done),
            renderMessage(template, h, stats: stats, userName: s.userName, n: k + 1, done: done),
            k,
          ));
        }
      }
    }
    return out;
  }

  static NotificationDetails _details(Habit h, Reminder r, String payload, String body, {required bool nag}) {
    final counter = h.target > 1;
    final androidActions = <AndroidNotificationAction>[
      AndroidNotificationAction(counter ? 'inc' : 'done', counter ? '+1 ${h.unit}'.trim() : '✓ C\'est fait',
          cancelNotification: true),
      if (h.miniVersion.isNotEmpty) const AndroidNotificationAction('mini', '🤏 Version mini', cancelNotification: true),
      const AndroidNotificationAction('snooze', '⏰ Plus tard', cancelNotification: true),
    ];
    return NotificationDetails(
      android: AndroidNotificationDetails(
        nag ? 'rituel_nags' : 'rituel_reminders',
        nag ? 'Relances insistantes' : 'Rappels',
        importance: nag ? Importance.max : Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        color: Color(h.color),
        styleInformation: BigTextStyleInformation(body),
        actions: androidActions,
        tag: h.id,
        onlyAlertOnce: false,
        autoCancel: true,
      ),
      windows: WindowsNotificationDetails(
        actions: [
          WindowsAction(content: counter ? '+1' : '✓ C\'est fait', arguments: 'act:${counter ? 'inc' : 'done'}|$payload'),
          if (h.miniVersion.isNotEmpty) WindowsAction(content: '🤏 Version mini', arguments: 'act:mini|$payload'),
          WindowsAction(content: '⏰ Plus tard', arguments: 'act:snooze|$payload'),
        ],
      ),
    );
  }

  static int _freeId(Map<int, String> used) {
    final rnd = Random();
    while (true) {
      final id = 1000 + rnd.nextInt(0x7FFFFFF0);
      if (!used.containsKey(id)) return id;
    }
  }

  static Future<void> _schedule(AppData data, List<_Planned> items) async {
    final mode = await _scheduleMode();
    for (final p in items) {
      final id = _freeId(data.scheduled);
      final payload = '${p.habit.id}|${dayKey(p.day)}|${p.reminder.id}';
      try {
        await _plugin.zonedSchedule(
          id: id,
          scheduledDate: tz.TZDateTime.from(p.time, tz.local),
          notificationDetails: _details(p.habit, p.reminder, payload, p.body, nag: p.nagIndex > 0),
          androidScheduleMode: mode,
          title: p.title,
          body: p.body,
          payload: payload,
        );
        data.scheduled[id] = '${p.habit.id}|${dayKey(p.day)}';
      } catch (e) {
        debugPrint('schedule failed: $e');
      }
    }
  }

  static Future<void> _cancelWhere(AppData data, bool Function(String v) test) async {
    final ids = data.scheduled.entries.where((e) => test(e.value)).map((e) => e.key).toList();
    for (final id in ids) {
      try {
        await _plugin.cancel(id: id);
      } catch (_) {}
      data.scheduled.remove(id);
    }
  }

  /// Rebuilds the whole rolling window of reminders. Call on app start/resume.
  static Future<void> rescheduleAll(AppData data) async {
    if (!supported) return;
    await init();
    await _cancelWhere(data, (_) => true);
    final now = DateTime.now();
    final plans = <_Planned>[];
    for (final h in data.habits) {
      plans.addAll(_plan(h, data.settings, now));
    }
    // Main reminders first, then the nearest follow-ups, within the OS budget.
    plans.sort((a, b) {
      final c = (a.nagIndex == 0 ? 0 : 1).compareTo(b.nagIndex == 0 ? 0 : 1);
      return c != 0 ? c : a.time.compareTo(b.time);
    });
    await _schedule(data, plans.take(_maxScheduled).toList());
  }

  /// Reschedules a single habit (after edit/creation/deletion).
  static Future<void> rescheduleHabit(AppData data, String habitId) async {
    if (!supported) return;
    await init();
    await _cancelWhere(data, (v) => v.startsWith('$habitId|'));
    final h = data.habit(habitId);
    if (h == null) return;
    final budget = max(0, _maxScheduled - data.scheduled.length);
    final plans = _plan(h, data.settings, DateTime.now())..sort((a, b) => a.time.compareTo(b.time));
    await _schedule(data, plans.take(budget).toList());
  }

  /// The habit was completed (or un-completed) on [day]: stop or restore its reminders.
  static Future<void> onHabitDayChanged(AppData data, Habit h, DateTime day) async {
    if (!supported) return;
    await init();
    if (isDoneOn(h, day)) {
      await _cancelWhere(data, (v) => v == '${h.id}|${dayKey(day)}');
    } else {
      await rescheduleHabit(data, h.id);
    }
  }

  static Future<void> snooze(AppData data, Habit h, String reminderId) async {
    if (!supported) return;
    await init();
    final r = h.reminders.firstWhere((r) => r.id == reminderId,
        orElse: () => h.reminders.isNotEmpty ? h.reminders.first : Reminder());
    final at = DateTime.now().add(Duration(minutes: data.settings.snoozeMinutes));
    final day = today();
    final stats = computeStats(h);
    final id = _freeId(data.scheduled);
    final payload = '${h.id}|${dayKey(day)}|${r.id}';
    final body = renderMessage(r.body, h, stats: stats, userName: data.settings.userName, done: countOn(h, day));
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details(h, r, payload, body, nag: true),
      androidScheduleMode: await _scheduleMode(),
      title: renderMessage(r.title, h, stats: stats, userName: data.settings.userName),
      body: body,
      payload: payload,
    );
    data.scheduled[id] = '${h.id}|${dayKey(day)}';
  }

  /// Sends a notification right now to preview a reminder's texts.
  static Future<void> preview(Habit h, Reminder r, AppSettings s, {bool nag = false}) async {
    if (!supported) return;
    await init();
    final stats = computeStats(h);
    final pool = r.nagMessages.where((m) => m.trim().isNotEmpty).toList();
    final nagPool = pool.isNotEmpty ? pool : s.defaultNagMessages;
    final template = nag && nagPool.isNotEmpty ? nagPool.first : r.body;
    final body = renderMessage(template, h, stats: stats, userName: s.userName, n: nag ? 2 : 1);
    await _plugin.show(
      id: 7,
      title: renderMessage(r.title, h, stats: stats, userName: s.userName, n: nag ? 2 : 1),
      body: body,
      notificationDetails: _details(h, r, '${h.id}|${dayKey(today())}|${r.id}', body, nag: nag),
      payload: '${h.id}|${dayKey(today())}|${r.id}',
    );
  }

  static Future<int> pendingCount() async {
    if (!supported) return 0;
    await init();
    try {
      return (await _plugin.pendingNotificationRequests()).length;
    } catch (_) {
      return -1;
    }
  }
}
