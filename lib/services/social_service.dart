import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/dates.dart';
import '../data/repository.dart';
import '../logic/gamification.dart';
import '../logic/stats.dart';
import '../models/app_settings.dart';
import '../models/habit.dart';
import '../models/social.dart';

/// Multiplayer layer: accounts, friends, shared stats and challenges.
class SocialService extends ChangeNotifier {
  bool configured = false;
  bool busy = false;
  String? lastError;

  Profile? me;
  List<Friendship> friendships = [];
  List<Challenge> challenges = [];
  StreamSubscription<AuthState>? _authSub;

  SupabaseClient get _db => Supabase.instance.client;
  User? get user => configured ? _db.auth.currentUser : null;
  bool get signedIn => user != null;

  List<Friendship> get friends => friendships.where((f) => f.status == 'accepted').toList();
  List<Friendship> get incoming => friendships.where((f) => f.status == 'pending' && f.incoming).toList();
  List<Friendship> get outgoing => friendships.where((f) => f.status == 'pending' && !f.incoming).toList();

  Future<void> init(AppSettings s) async {
    final url = s.supabaseUrl.isNotEmpty ? s.supabaseUrl : AppConfig.supabaseUrl;
    final key = s.supabaseAnonKey.isNotEmpty ? s.supabaseAnonKey : AppConfig.supabaseKey;
    if (url.isEmpty || key.isEmpty) return;
    try {
      await Supabase.initialize(url: url.trim(), publishableKey: key.trim());
      configured = true;
      _authSub = _db.auth.onAuthStateChange.listen((_) => refresh());
      if (signedIn) unawaited(refresh());
    } catch (e) {
      lastError = 'Connexion au serveur impossible : $e';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<T?> _guard<T>(Future<T> Function() f) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      return await f();
    } on AuthException catch (e) {
      lastError = _translateAuth(e.message);
    } on PostgrestException catch (e) {
      lastError = e.code == '23505' ? 'Ce nom est déjà pris.' : e.message;
    } catch (e) {
      lastError = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
    return null;
  }

  String _translateAuth(String m) {
    final l = m.toLowerCase();
    if (l.contains('invalid login')) return 'Email ou mot de passe incorrect.';
    if (l.contains('already registered')) return 'Un compte existe déjà avec cet email.';
    if (l.contains('password')) return 'Mot de passe trop faible (6 caractères minimum).';
    if (l.contains('email not confirmed')) return 'Confirme ton email (lien reçu par mail) puis reconnecte-toi.';
    return m;
  }

  // ------------------------------------------------------------------ auth

  Future<bool> signUp(String email, String password, String username, String displayName) async {
    final ok = await _guard(() async {
      final clean = username.trim().toLowerCase();
      if (!RegExp(r'^[a-z0-9_.]{3,24}$').hasMatch(clean)) {
        throw 'Pseudo : 3 à 24 caractères (lettres, chiffres, _ ou .)';
      }
      final taken = await _db.from('profiles').select('id').eq('username', clean).maybeSingle();
      if (taken != null) throw 'Ce pseudo est déjà pris.';
      final res = await _db.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'username': clean, 'display_name': displayName.trim()},
      );
      if (res.session == null) {
        throw 'Compte créé ! Confirme ton email (lien reçu par mail) puis connecte-toi.';
      }
      return true;
    });
    if (ok == true) await refresh();
    return ok == true;
  }

  Future<bool> signIn(String email, String password) async {
    final ok = await _guard(() async {
      await _db.auth.signInWithPassword(email: email.trim(), password: password);
      return true;
    });
    if (ok == true) await refresh();
    return ok == true;
  }

  Future<void> signOut() async {
    await _guard(() => _db.auth.signOut());
    me = null;
    friendships = [];
    challenges = [];
    notifyListeners();
  }

  Future<void> updateProfile({String? displayName, String? avatar}) async {
    final uid = user?.id;
    if (uid == null) return;
    await _guard(() => _db.from('profiles').update({
          'display_name': ?displayName,
          'avatar_emoji': ?avatar,
        }).eq('id', uid));
    await refresh();
  }

  // ---------------------------------------------------------------- loading

  Future<void> refresh() async {
    final uid = user?.id;
    if (uid == null) {
      notifyListeners();
      return;
    }
    try {
      final p = await _db.from('profiles').select().eq('id', uid).maybeSingle();
      me = p == null ? null : Profile.fromJson(p);

      final rows = await _db
          .from('friendships')
          .select('id, status, requester, addressee')
          .or('requester.eq.$uid,addressee.eq.$uid');
      final otherIds = <String>{
        for (final r in rows) (r['requester'] == uid ? r['addressee'] : r['requester']) as String,
      };
      final profiles = otherIds.isEmpty
          ? <String, Profile>{}
          : {
              for (final p in await _db.from('profiles').select().inFilter('id', otherIds.toList()))
                p['id'] as String: Profile.fromJson(p),
            };
      friendships = [
        for (final r in rows)
          if (profiles[(r['requester'] == uid ? r['addressee'] : r['requester']) as String] case final other?)
            Friendship((r['id'] as num).toInt(), other, r['status'] as String, r['addressee'] == uid),
      ];

      final ch = await _db.from('challenge_members').select('challenges(*)').eq('user_id', uid);
      challenges = [
        for (final r in ch)
          if (r['challenges'] != null) Challenge.fromJson(Map<String, dynamic>.from(r['challenges'] as Map)),
      ];
      lastError = null;
    } catch (e) {
      lastError = 'Synchronisation impossible : $e';
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- friends

  /// Adds a friend by pseudo or friend code. Accepts automatically if they already asked.
  Future<String?> addFriend(String query) async {
    final uid = user?.id;
    if (uid == null) return null;
    final q = query.trim();
    final res = await _guard<String>(() async {
      var target = await _db.from('profiles').select().eq('friend_code', q.toUpperCase()).maybeSingle();
      target ??= await _db.from('profiles').select().eq('username', q.toLowerCase()).maybeSingle();
      if (target == null) throw 'Aucun utilisateur « $q ».';
      final other = target['id'] as String;
      if (other == uid) throw 'C\'est toi 😄';
      final existing = await _db
          .from('friendships')
          .select()
          .or('and(requester.eq.$uid,addressee.eq.$other),and(requester.eq.$other,addressee.eq.$uid)')
          .maybeSingle();
      if (existing != null) {
        if (existing['status'] == 'accepted') throw 'Vous êtes déjà amis.';
        if (existing['addressee'] == uid) {
          await _db.from('friendships').update({'status': 'accepted'}).eq('id', existing['id']);
          return 'Vous êtes maintenant amis 🤝';
        }
        throw 'Demande déjà envoyée.';
      }
      await _db.from('friendships').insert({'requester': uid, 'addressee': other});
      return 'Demande envoyée à ${target['username']} ✉️';
    });
    await refresh();
    return res;
  }

  Future<void> accept(Friendship f) async {
    await _guard(() => _db.from('friendships').update({'status': 'accepted'}).eq('id', f.id));
    await refresh();
  }

  Future<void> removeFriendship(Friendship f) async {
    await _guard(() => _db.from('friendships').delete().eq('id', f.id));
    await refresh();
  }

  Future<List<FriendHabit>> friendHabits(String userId) async {
    final rows = await _db.from('habit_stats').select().eq('user_id', userId).order('score', ascending: false);
    return rows.map(FriendHabit.fromJson).toList();
  }

  // ------------------------------------------------------------------- sync

  /// Publishes my stats so friends can compare. Called after changes (debounced).
  Future<void> syncStats(AppData data) async {
    final uid = user?.id;
    if (uid == null) return;
    try {
      final t = today();
      final g = computeGlobal(data.habits, t);
      await _db.from('profiles').update({
        'xp': g.xp,
        'level': g.level.number,
        'perfect_days': g.perfectDays,
        'best_streak': g.bestStreak,
        'avg_score': g.avgScore,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);

      final shared = data.habits.where((h) => !h.archived && (h.shareWithFriends || h.challengeId != null)).toList();
      if (shared.isNotEmpty) {
        await _db.from('habit_stats').upsert([
          for (final h in shared)
            {
              'user_id': uid,
              'habit_id': h.id,
              'name': h.name,
              'emoji': h.emoji,
              'color': h.color,
              'current_streak': g.perHabit[h.id]?.currentStreak ?? 0,
              'best_streak': g.perHabit[h.id]?.bestStreak ?? 0,
              'score': g.perHabit[h.id]?.score ?? 0,
              'rate30': g.perHabit[h.id]?.rate30 ?? 0,
              'total': g.perHabit[h.id]?.total ?? 0,
              'done_today': isDoneOn(h, t),
              'last7': lastDaysPattern(h, 7, t),
              'challenge_id': h.challengeId,
              'is_public': h.shareWithFriends,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
        ]);
      }
      final keep = shared.map((h) => h.id).toList();
      var del = _db.from('habit_stats').delete().eq('user_id', uid);
      if (keep.isNotEmpty) del = del.not('habit_id', 'in', '(${keep.map((e) => '"$e"').join(',')})');
      await del;

      // Challenge check-ins for the last 30 days.
      for (final h in data.habits.where((h) => h.challengeId != null)) {
        final done = <String>[], notDone = <String>[];
        for (var i = 0; i < 30; i++) {
          final d = addDays(t, -i);
          (isDoneOn(h, d) ? done : notDone).add(dayKey(d));
        }
        if (done.isNotEmpty) {
          await _db.from('challenge_checkins').upsert([
            for (final d in done) {'challenge_id': h.challengeId, 'user_id': uid, 'day': d},
          ], ignoreDuplicates: true);
        }
        if (notDone.isNotEmpty) {
          await _db
              .from('challenge_checkins')
              .delete()
              .eq('challenge_id', h.challengeId!)
              .eq('user_id', uid)
              .inFilter('day', notDone);
        }
      }
    } catch (e) {
      debugPrint('sync failed: $e');
    }
  }

  // ------------------------------------------------------------- challenges

  Future<Challenge?> createChallenge(Habit h, String description) async {
    final uid = user?.id;
    if (uid == null) return null;
    final c = await _guard(() async {
      final row = await _db
          .from('challenges')
          .insert({
            'name': h.name,
            'emoji': h.emoji,
            'color': h.color,
            'description': description,
            'target': h.target,
            'unit': h.unit,
            'weekdays': h.frequency == FrequencyType.weekdays ? (h.weekdays.toList()..sort()) : [1, 2, 3, 4, 5, 6, 7],
            'created_by': uid,
          })
          .select()
          .single();
      final c = Challenge.fromJson(row);
      await _db.from('challenge_members').insert({'challenge_id': c.id, 'user_id': uid});
      return c;
    });
    await refresh();
    return c;
  }

  Future<Challenge?> joinChallenge(String code) async {
    final uid = user?.id;
    if (uid == null) return null;
    final c = await _guard(() async {
      final row = await _db.from('challenges').select().eq('invite_code', code.trim().toUpperCase()).maybeSingle();
      if (row == null) throw 'Code de défi introuvable.';
      final c = Challenge.fromJson(row);
      await _db.from('challenge_members').upsert({'challenge_id': c.id, 'user_id': uid}, ignoreDuplicates: true);
      return c;
    });
    await refresh();
    return c;
  }

  Future<void> leaveChallenge(Challenge c) async {
    final uid = user?.id;
    if (uid == null) return;
    await _guard(() => _db.from('challenge_members').delete().eq('challenge_id', c.id).eq('user_id', uid));
    await refresh();
  }

  Future<List<LeaderboardEntry>> leaderboard(Challenge c) async {
    final t = today();
    final from = addDays(t, -29);
    final members = await _db.from('challenge_members').select('user_id, joined_at').eq('challenge_id', c.id);
    final ids = members.map((m) => m['user_id'] as String).toList();
    if (ids.isEmpty) return [];
    final profiles = {
      for (final p in await _db.from('profiles').select().inFilter('id', ids)) p['id'] as String: Profile.fromJson(p),
    };
    final checkins = await _db
        .from('challenge_checkins')
        .select('user_id, day')
        .eq('challenge_id', c.id)
        .gte('day', dayKey(addDays(t, -120)));
    final byUser = <String, Set<String>>{};
    for (final r in checkins) {
      byUser.putIfAbsent(r['user_id'] as String, () => {}).add(r['day'] as String);
    }
    bool sched(DateTime d) => c.weekdays.contains(d.weekday);

    final out = <LeaderboardEntry>[];
    for (final m in members) {
      final uid = m['user_id'] as String;
      final p = profiles[uid];
      if (p == null) continue;
      final days = byUser[uid] ?? {};
      final joined = dateOnly(DateTime.tryParse(m['joined_at'] as String? ?? '')?.toLocal() ?? t);
      final start = joined.isAfter(from) ? joined : from;
      var scheduled = 0, done = 0;
      for (var d = start; !d.isAfter(t); d = addDays(d, 1)) {
        if (!sched(d)) continue;
        final isDone = days.contains(dayKey(d));
        if (d == t && !isDone) continue;
        scheduled++;
        if (isDone) done++;
      }
      var streak = 0;
      var d = days.contains(dayKey(t)) ? t : addDays(t, -1);
      for (var i = 0; i < 120; i++, d = addDays(d, -1)) {
        if (!sched(d)) continue;
        if (!days.contains(dayKey(d))) break;
        streak++;
      }
      out.add(LeaderboardEntry(
        profile: p,
        rate: scheduled == 0 ? 0 : done / scheduled,
        streak: streak,
        total: days.where((k) => !parseDayKey(k).isBefore(from)).length,
        doneToday: days.contains(dayKey(t)),
        last14: [
          for (var i = 13; i >= 0; i--)
            if (addDays(t, -i).isBefore(joined)) null else if (!sched(addDays(t, -i))) null else days.contains(dayKey(addDays(t, -i))),
        ],
      ));
    }
    out.sort((a, b) {
      final r = b.rate.compareTo(a.rate);
      if (r != 0) return r;
      final s = b.streak.compareTo(a.streak);
      return s != 0 ? s : b.total.compareTo(a.total);
    });
    return out;
  }

  /// Friendly "versus" summary used on a friend's page.
  static ({double mine, double theirs}) compareScores(List<double> mine, List<double> theirs) {
    double avg(List<double> l) => l.isEmpty ? 0 : l.reduce((a, b) => a + b) / l.length;
    return (mine: avg(mine), theirs: avg(theirs));
  }
}
