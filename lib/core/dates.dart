import 'package:intl/intl.dart';

/// Helpers around "calendar days" (no time component).

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => dateOnly(DateTime.now());

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String key) {
  final p = key.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// Adds [days] calendar days (DST-safe, unlike Duration(days: n)).
DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// Monday of the week containing [d].
DateTime weekStart(DateTime d) => addDays(dateOnly(d), -(d.weekday - 1));

int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

const weekdayShort = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const weekdayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

String prettyDate(DateTime d) {
  final s = DateFormat('EEEE d MMMM', 'fr_FR').format(d);
  return s[0].toUpperCase() + s.substring(1);
}

String hm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 5) return 'Bonne nuit';
  if (h < 12) return 'Bonjour';
  if (h < 18) return 'Bon après-midi';
  return 'Bonsoir';
}
