import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newId() => _uuid.v4();

enum FrequencyType { daily, weekdays, perWeek }

/// A reminder attached to a habit. Every text is user-editable and supports
/// placeholders (see [kPlaceholders]).
class Reminder {
  Reminder({
    String? id,
    this.hour = 9,
    this.minute = 0,
    this.enabled = true,
    this.title = '{emoji} {habitude}',
    this.body = "C'est le moment ! {pourquoi}",
    this.nag = false,
    this.nagIntervalMinutes = 15,
    this.nagMaxCount = 8,
    List<String>? nagMessages,
  })  : id = id ?? newId(),
        nagMessages = nagMessages ?? [];

  final String id;
  int hour;
  int minute;
  bool enabled;
  String title;
  String body;

  /// "Spam" mode: keep notifying every [nagIntervalMinutes] until the habit is done.
  bool nag;
  int nagIntervalMinutes;
  int nagMaxCount;

  /// Rotating messages used for the follow-up notifications. Empty = app defaults.
  List<String> nagMessages;

  Reminder copy() => Reminder.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
        'title': title,
        'body': body,
        'nag': nag,
        'nagIntervalMinutes': nagIntervalMinutes,
        'nagMaxCount': nagMaxCount,
        'nagMessages': nagMessages,
      };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as String?,
        hour: j['hour'] as int? ?? 9,
        minute: j['minute'] as int? ?? 0,
        enabled: j['enabled'] as bool? ?? true,
        title: j['title'] as String? ?? '{emoji} {habitude}',
        body: j['body'] as String? ?? '',
        nag: j['nag'] as bool? ?? false,
        nagIntervalMinutes: j['nagIntervalMinutes'] as int? ?? 15,
        nagMaxCount: j['nagMaxCount'] as int? ?? 8,
        nagMessages: (j['nagMessages'] as List?)?.cast<String>() ?? [],
      );
}

class Habit {
  Habit({
    String? id,
    required this.name,
    this.emoji = '✨',
    this.color = 0xFF7C5CFF,
    this.why = '',
    this.identity = '',
    this.cue = '',
    this.location = '',
    this.miniVersion = '',
    this.notes = '',
    this.frequency = FrequencyType.daily,
    Set<int>? weekdays,
    this.perWeek = 3,
    this.target = 1,
    this.unit = '',
    List<Reminder>? reminders,
    this.archived = false,
    this.shareWithFriends = true,
    DateTime? createdAt,
    this.order = 0,
    this.challengeId,
    Map<String, int>? log,
    Set<String>? miniDays,
    Set<String>? frozenDays,
  })  : id = id ?? newId(),
        weekdays = weekdays ?? {1, 2, 3, 4, 5, 6, 7},
        reminders = reminders ?? [],
        createdAt = createdAt ?? DateTime.now(),
        log = log ?? {},
        miniDays = miniDays ?? {},
        frozenDays = frozenDays ?? {};

  final String id;
  String name;
  String emoji;
  int color;

  // Psychology fields.
  /// The deep motivation ("Pourquoi c'est important pour moi").
  String why;

  /// Identity-based habit: "Je suis quelqu'un qui ..."
  String identity;

  /// Implementation intention / habit stacking: "Après mon café".
  String cue;
  String location;

  /// Two-minute rule: the smallest version that still counts.
  String miniVersion;
  String notes;

  FrequencyType frequency;

  /// ISO weekdays 1 (Mon) .. 7 (Sun), used when [frequency] == weekdays.
  Set<int> weekdays;

  /// Number of days per week, used when [frequency] == perWeek.
  int perWeek;

  /// Repetitions per day needed to count the day as done (e.g. 8 glasses).
  int target;
  String unit;

  List<Reminder> reminders;
  bool archived;
  bool shareWithFriends;
  DateTime createdAt;
  int order;

  /// When set, this habit is linked to a shared multiplayer challenge.
  String? challengeId;

  /// dayKey -> count done that day.
  Map<String, int> log;

  /// Days validated with the "mini version" (two-minute rule).
  Set<String> miniDays;

  /// Days protected by a streak freeze.
  Set<String> frozenDays;

  Habit copy() => Habit.fromJson(toJson());

  String get frequencyLabel {
    switch (frequency) {
      case FrequencyType.daily:
        return 'Tous les jours';
      case FrequencyType.perWeek:
        return '$perWeek× par semaine';
      case FrequencyType.weekdays:
        if (weekdays.length == 5 && !weekdays.contains(6) && !weekdays.contains(7)) {
          return 'En semaine';
        }
        if (weekdays.length == 2 && weekdays.containsAll({6, 7})) return 'Le week-end';
        const n = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
        final l = weekdays.toList()..sort();
        return l.map((d) => n[d - 1]).join(' · ');
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': color,
        'why': why,
        'identity': identity,
        'cue': cue,
        'location': location,
        'miniVersion': miniVersion,
        'notes': notes,
        'frequency': frequency.name,
        'weekdays': weekdays.toList()..sort(),
        'perWeek': perWeek,
        'target': target,
        'unit': unit,
        'reminders': reminders.map((r) => r.toJson()).toList(),
        'archived': archived,
        'shareWithFriends': shareWithFriends,
        'createdAt': createdAt.toIso8601String(),
        'order': order,
        'challengeId': challengeId,
        'log': log,
        'miniDays': miniDays.toList(),
        'frozenDays': frozenDays.toList(),
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String?,
        name: j['name'] as String? ?? 'Habitude',
        emoji: j['emoji'] as String? ?? '✨',
        color: j['color'] as int? ?? 0xFF7C5CFF,
        why: j['why'] as String? ?? '',
        identity: j['identity'] as String? ?? '',
        cue: j['cue'] as String? ?? '',
        location: j['location'] as String? ?? '',
        miniVersion: j['miniVersion'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        frequency: FrequencyType.values.firstWhere(
          (f) => f.name == j['frequency'],
          orElse: () => FrequencyType.daily,
        ),
        weekdays: (j['weekdays'] as List?)?.cast<int>().toSet(),
        perWeek: j['perWeek'] as int? ?? 3,
        target: j['target'] as int? ?? 1,
        unit: j['unit'] as String? ?? '',
        reminders: (j['reminders'] as List?)
            ?.map((r) => Reminder.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList(),
        archived: j['archived'] as bool? ?? false,
        shareWithFriends: j['shareWithFriends'] as bool? ?? true,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
        order: j['order'] as int? ?? 0,
        challengeId: j['challengeId'] as String?,
        log: (j['log'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())),
        miniDays: (j['miniDays'] as List?)?.cast<String>().toSet(),
        frozenDays: (j['frozenDays'] as List?)?.cast<String>().toSet(),
      );
}
