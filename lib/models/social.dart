class Profile {
  Profile({
    required this.id,
    required this.username,
    this.displayName = '',
    this.avatar = '🙂',
    this.friendCode = '',
    this.level = 1,
    this.xp = 0,
    this.perfectDays = 0,
    this.bestStreak = 0,
    this.avgScore = 0,
    this.updatedAt,
  });

  final String id;
  final String username;
  final String displayName;
  final String avatar;
  final String friendCode;
  final int level;
  final int xp;
  final int perfectDays;
  final int bestStreak;
  final double avgScore;
  final DateTime? updatedAt;

  String get label => displayName.isNotEmpty ? displayName : username;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        username: j['username'] as String? ?? '',
        displayName: j['display_name'] as String? ?? '',
        avatar: j['avatar_emoji'] as String? ?? '🙂',
        friendCode: j['friend_code'] as String? ?? '',
        level: (j['level'] as num?)?.toInt() ?? 1,
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        perfectDays: (j['perfect_days'] as num?)?.toInt() ?? 0,
        bestStreak: (j['best_streak'] as num?)?.toInt() ?? 0,
        avgScore: (j['avg_score'] as num?)?.toDouble() ?? 0,
        updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? ''),
      );
}

class Friendship {
  Friendship(this.id, this.other, this.status, this.incoming);
  final int id;
  final Profile other;
  final String status; // pending | accepted
  final bool incoming;
}

class FriendHabit {
  FriendHabit({
    required this.habitId,
    required this.name,
    required this.emoji,
    required this.color,
    required this.currentStreak,
    required this.bestStreak,
    required this.score,
    required this.rate30,
    required this.total,
    required this.doneToday,
    required this.last7,
    this.challengeId,
  });

  final String habitId;
  final String name;
  final String emoji;
  final int color;
  final int currentStreak;
  final int bestStreak;
  final double score;
  final double rate30;
  final int total;
  final bool doneToday;
  final String last7;
  final String? challengeId;

  factory FriendHabit.fromJson(Map<String, dynamic> j) => FriendHabit(
        habitId: j['habit_id'] as String,
        name: j['name'] as String? ?? '',
        emoji: j['emoji'] as String? ?? '✨',
        color: (j['color'] as num?)?.toInt() ?? 0xFF7C5CFF,
        currentStreak: (j['current_streak'] as num?)?.toInt() ?? 0,
        bestStreak: (j['best_streak'] as num?)?.toInt() ?? 0,
        score: (j['score'] as num?)?.toDouble() ?? 0,
        rate30: (j['rate30'] as num?)?.toDouble() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        doneToday: j['done_today'] as bool? ?? false,
        last7: j['last7'] as String? ?? '',
        challengeId: j['challenge_id'] as String?,
      );
}

class Challenge {
  Challenge({
    required this.id,
    required this.name,
    this.emoji = '⚔️',
    this.color = 0xFFFF5C8A,
    this.description = '',
    this.target = 1,
    this.unit = '',
    this.weekdays = const [1, 2, 3, 4, 5, 6, 7],
    this.inviteCode = '',
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String name;
  final String emoji;
  final int color;
  final String description;
  final int target;
  final String unit;
  final List<int> weekdays;
  final String inviteCode;
  final String? createdBy;
  final DateTime? createdAt;

  factory Challenge.fromJson(Map<String, dynamic> j) => Challenge(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Défi',
        emoji: j['emoji'] as String? ?? '⚔️',
        color: (j['color'] as num?)?.toInt() ?? 0xFFFF5C8A,
        description: j['description'] as String? ?? '',
        target: (j['target'] as num?)?.toInt() ?? 1,
        unit: j['unit'] as String? ?? '',
        weekdays: (j['weekdays'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [1, 2, 3, 4, 5, 6, 7],
        inviteCode: j['invite_code'] as String? ?? '',
        createdBy: j['created_by'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
      );
}

class LeaderboardEntry {
  LeaderboardEntry({
    required this.profile,
    required this.rate,
    required this.streak,
    required this.total,
    required this.doneToday,
    required this.last14,
  });

  final Profile profile;
  final double rate;
  final int streak;
  final int total;
  final bool doneToday;

  /// Oldest -> newest, true = checked in.
  final List<bool?> last14;
}
