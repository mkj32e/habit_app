import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/dates.dart';
import '../models/app_settings.dart';
import '../models/habit.dart';

/// Everything the app persists, in a single JSON document.
class AppData {
  AppData({List<Habit>? habits, AppSettings? settings, Map<int, String>? scheduled})
      : habits = habits ?? [],
        settings = settings ?? AppSettings(),
        scheduled = scheduled ?? {};

  final List<Habit> habits;
  AppSettings settings;

  /// Index of scheduled notifications: notification id -> "habitId|dayKey".
  /// Lets us cancel a habit's pending reminders on any platform without
  /// relying on plugin payload support.
  final Map<int, String> scheduled;

  Habit? habit(String id) {
    for (final h in habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'habits': habits.map((h) => h.toJson()).toList(),
        'settings': settings.toJson(),
        'scheduled': scheduled.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        habits: (j['habits'] as List? ?? [])
            .map((h) => Habit.fromJson(Map<String, dynamic>.from(h as Map)))
            .toList(),
        settings: j['settings'] == null
            ? AppSettings()
            : AppSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map)),
        scheduled: (j['scheduled'] as Map?)
            ?.map((k, v) => MapEntry(int.parse(k as String), v as String)),
      );
}

/// File based persistence. Safe to use from background isolates
/// (notification actions, home screen widget taps).
class Repository {
  static File? _file;

  static Future<File> _dataFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return _file = File('${dir.path}${Platform.pathSeparator}rituel_data.json');
  }

  static Future<AppData> load() async {
    final f = await _dataFile();
    if (!await f.exists()) return AppData();
    try {
      return AppData.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      // Corrupted file: keep a copy and start fresh rather than crash.
      await f.copy('${f.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      return AppData();
    }
  }

  static Future<void> save(AppData data) async {
    final f = await _dataFile();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  static Future<String> exportJson(AppData data) async =>
      const JsonEncoder.withIndent('  ').convert(data.toJson());

  static AppData importJson(String raw) =>
      AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

/// Mutations shared by the UI store and the background handlers.
class HabitOps {
  /// Records one repetition. Returns true if the day just became complete.
  static bool increment(Habit h, DateTime day, {int by = 1}) {
    final k = dayKey(day);
    final before = (h.log[k] ?? 0) >= h.target;
    final v = ((h.log[k] ?? 0) + by).clamp(0, h.target);
    if (v == 0) {
      h.log.remove(k);
    } else {
      h.log[k] = v;
    }
    return !before && v >= h.target;
  }

  static void setDone(Habit h, DateTime day, bool done) {
    final k = dayKey(day);
    if (done) {
      h.log[k] = h.target;
    } else {
      h.log.remove(k);
      h.miniDays.remove(k);
    }
  }

  static void markMini(Habit h, DateTime day) {
    final k = dayKey(day);
    h.miniDays.add(k);
    h.log[k] = h.target;
  }
}
