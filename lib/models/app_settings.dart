import 'package:flutter/material.dart';

class AppSettings {
  AppSettings({
    this.userName = '',
    this.themeMode = ThemeMode.dark,
    this.accent = 0xFF7C5CFF,
    this.onboardingDone = false,
    this.celebrations = true,
    this.haptics = true,
    this.snoozeMinutes = 10,
    this.nagStartHour = 7,
    this.nagStopHour = 23,
    List<String>? defaultNagMessages,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    Set<String>? seenBadges,
    this.miniAlwaysOnTop = true,
  })  : defaultNagMessages = defaultNagMessages ?? List.of(kDefaultNagMessages),
        seenBadges = seenBadges ?? {};

  String userName;
  ThemeMode themeMode;
  int accent;
  bool onboardingDone;
  bool celebrations;
  bool haptics;
  int snoozeMinutes;

  /// "Spam" notifications are never sent outside of [nagStartHour, nagStopHour[.
  int nagStartHour;
  int nagStopHour;
  List<String> defaultNagMessages;

  /// Optional runtime override of the multiplayer backend.
  String supabaseUrl;
  String supabaseAnonKey;

  Set<String> seenBadges;
  bool miniAlwaysOnTop;

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'themeMode': themeMode.name,
        'accent': accent,
        'onboardingDone': onboardingDone,
        'celebrations': celebrations,
        'haptics': haptics,
        'snoozeMinutes': snoozeMinutes,
        'nagStartHour': nagStartHour,
        'nagStopHour': nagStopHour,
        'defaultNagMessages': defaultNagMessages,
        'supabaseUrl': supabaseUrl,
        'supabaseAnonKey': supabaseAnonKey,
        'seenBadges': seenBadges.toList(),
        'miniAlwaysOnTop': miniAlwaysOnTop,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        userName: j['userName'] as String? ?? '',
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == j['themeMode'],
          orElse: () => ThemeMode.dark,
        ),
        accent: j['accent'] as int? ?? 0xFF7C5CFF,
        onboardingDone: j['onboardingDone'] as bool? ?? false,
        celebrations: j['celebrations'] as bool? ?? true,
        haptics: j['haptics'] as bool? ?? true,
        snoozeMinutes: j['snoozeMinutes'] as int? ?? 10,
        nagStartHour: j['nagStartHour'] as int? ?? 7,
        nagStopHour: j['nagStopHour'] as int? ?? 23,
        defaultNagMessages: (j['defaultNagMessages'] as List?)?.cast<String>(),
        supabaseUrl: j['supabaseUrl'] as String? ?? '',
        supabaseAnonKey: j['supabaseAnonKey'] as String? ?? '',
        seenBadges: (j['seenBadges'] as List?)?.cast<String>().toSet(),
        miniAlwaysOnTop: j['miniAlwaysOnTop'] as bool? ?? true,
      );
}

/// Escalating follow-up messages used by "spam" mode when a reminder has no
/// custom list. Fully editable in the settings.
const kDefaultNagMessages = [
  '{emoji} {habitude} t\'attend toujours. 2 minutes suffisent : {mini}',
  'Petit rappel n°{n} : ta série de {serie} jours compte sur toi 🔥',
  'Rappelle-toi pourquoi : {pourquoi}',
  'Tu es quelqu\'un qui {identite}. Prouve-le maintenant 💪',
  'Je vais continuer à te relancer jusqu\'à ce que ce soit fait 😈',
  'Allez {prenom}, on ne rate jamais deux fois !',
];
