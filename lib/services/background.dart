import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/dates.dart';
import '../data/repository.dart';
import '../logic/stats.dart';
import 'notification_service.dart';
import 'widget_service.dart';

/// Entry point for notification actions when the app is not in the foreground
/// (Android runs it in a background isolate).
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final a = NotifAction.parse(response);
  if (a != null) await BackgroundActions.handle(a);
}

/// Entry point for taps on the home screen widget (habitapp://toggle?id=...).
@pragma('vm:entry-point')
Future<void> widgetInteractivityCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  if (uri == null || uri.host != 'toggle') return;
  final id = uri.queryParameters['id'];
  if (id == null) return;
  await BackgroundActions.toggleFromWidget(id);
}

class BackgroundActions {
  static Future<void> handle(NotifAction a) async {
    final data = await Repository.load();
    final h = data.habit(a.habitId);
    if (h == null) return;
    await NotificationService.init(background: true);
    switch (a.action) {
      case 'done':
        HabitOps.setDone(h, a.day, true);
      case 'inc':
        HabitOps.increment(h, a.day);
      case 'mini':
        HabitOps.markMini(h, a.day);
      case 'snooze':
        await NotificationService.snooze(data, h, a.reminderId);
        await Repository.save(data);
        return;
      default:
        return;
    }
    await NotificationService.onHabitDayChanged(data, h, a.day);
    await Repository.save(data);
    await WidgetService.update(data);
  }

  static Future<void> toggleFromWidget(String habitId) async {
    final data = await Repository.load();
    final h = data.habit(habitId);
    if (h == null) return;
    final t = today();
    if (isDoneOn(h, t)) {
      HabitOps.setDone(h, t, false);
    } else if (h.target > 1) {
      HabitOps.increment(h, t);
    } else {
      HabitOps.setDone(h, t, true);
    }
    await NotificationService.init(background: true);
    await NotificationService.onHabitDayChanged(data, h, t);
    await Repository.save(data);
    await WidgetService.update(data);
  }
}
