import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/habit_store.dart';
import '../../models/habit.dart';
import '../../models/social.dart';
import '../../services/social_service.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import 'challenge_screen.dart';
import 'friend_screen.dart';
import 'settings_screen.dart';

class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    Widget body;
    if (!social.configured) {
      body = const _NotConfigured();
    } else if (!social.signedIn) {
      body = const _AuthView();
    } else {
      body = const _SocialHome();
    }
    return Scaffold(body: SafeArea(bottom: false, child: ContentWidth(child: body)));
  }
}

class _NotConfigured extends StatelessWidget {
  const _NotConfigured();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          Text('Amis & défis', style: context.tt.headlineMedium),
          const SizedBox(height: 8),
          EmptyState(
            emoji: '🤝',
            title: 'Le multijoueur n\'est pas encore activé',
            message:
                'Pour comparer tes habitudes avec tes amis, l\'app a besoin d\'un petit serveur gratuit (Supabase). '
                'Le fichier README explique comment le créer en 5 minutes, puis colle son adresse et sa clé dans les réglages.',
            action: FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
              icon: const Icon(Icons.settings_rounded),
              label: const Text('Ouvrir les réglages'),
            ),
          ),
        ],
      );
}

class _AuthView extends StatefulWidget {
  const _AuthView();

  @override
  State<_AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<_AuthView> {
  bool signup = true;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _username = TextEditingController();
  final _display = TextEditingController();

  @override
  void dispose() {
    for (final c in [_email, _password, _username, _display]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final social = context.read<SocialService>();
    if (signup) {
      await social.signUp(_email.text, _password.text, _username.text, _display.text);
    } else {
      await social.signIn(_email.text, _password.text);
    }
    if (mounted && social.lastError != null) toast(context, social.lastError!);
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      children: [
        const Text('🤝', style: TextStyle(fontSize: 64), textAlign: TextAlign.center)
            .animate()
            .scale(curve: Curves.elasticOut, duration: 900.ms),
        const SizedBox(height: 12),
        Text('Ensemble, on tient mieux', style: context.tt.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Savoir que quelqu\'un regarde double la motivation. Ajoute tes amis, lancez des défis communs et voyez qui est le plus régulier.',
          style: context.tt.bodyMedium?.copyWith(color: context.subtle),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: true, label: Text('Créer un compte')),
            ButtonSegment(value: false, label: Text('Se connecter')),
          ],
          selected: {signup},
          onSelectionChanged: (s) => setState(() => signup = s.first),
        ),
        const SizedBox(height: 16),
        if (signup) ...[
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'Pseudo (unique)', prefixText: '@'),
          ),
          const SizedBox(height: 10),
          TextField(controller: _display, decoration: const InputDecoration(labelText: 'Prénom affiché')),
          const SizedBox(height: 10),
        ],
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _password,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Mot de passe'),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: social.busy ? null : _submit,
          child: social.busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(signup ? 'C\'est parti' : 'Connexion'),
        ),
      ],
    );
  }
}

class _SocialHome extends StatelessWidget {
  const _SocialHome();

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    final me = social.me;
    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text('Amis & défis', style: context.tt.headlineMedium)),
                    IconButton(
                      tooltip: 'Actualiser',
                      onPressed: social.refresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (me != null) _MyProfileCard(me: me),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabsHeader(
              TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: context.tt.titleSmall,
                tabs: [
                  Tab(text: 'Amis${social.incoming.isNotEmpty ? ' (${social.incoming.length})' : ''}'),
                  const Tab(text: 'Défis'),
                  const Tab(text: 'Classement'),
                ],
              ),
              context.theme.scaffoldBackgroundColor,
            ),
          ),
        ],
        body: const TabBarView(children: [_FriendsTab(), _ChallengesTab(), _RankingTab()]),
      ),
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader(this.tabs, this.bg);
  final TabBar tabs;
  final Color bg;
  @override
  double get minExtent => tabs.preferredSize.height;
  @override
  double get maxExtent => tabs.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: bg, child: tabs);
  @override
  bool shouldRebuild(_TabsHeader old) => old.tabs != tabs;
}

class _MyProfileCard extends StatelessWidget {
  const _MyProfileCard({required this.me});
  final Profile me;

  @override
  Widget build(BuildContext context) {
    final social = context.read<SocialService>();
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        GestureDetector(
          onTap: () async {
            final e = await pickEmoji(context, me.avatar);
            if (e != null) await social.updateProfile(avatar: e);
          },
          child: CircleAvatar(
            radius: 26,
            backgroundColor: context.cs.primary.withValues(alpha: 0.18),
            child: Text(me.avatar, style: const TextStyle(fontSize: 26)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(me.label, style: context.tt.titleMedium),
            Text('@${me.username} · Niv. ${me.level}', style: context.tt.bodySmall?.copyWith(color: context.subtle)),
          ]),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Clipboard.setData(ClipboardData(text: me.friendCode));
            toast(context, 'Code ami copié : ${me.friendCode}');
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Text('MON CODE', style: context.tt.labelSmall?.copyWith(color: context.subtle, fontSize: 9, letterSpacing: 1)),
              Text(me.friendCode, style: context.tt.titleSmall?.copyWith(letterSpacing: 2)),
            ]),
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'out') social.signOut();
          },
          itemBuilder: (_) => [const PopupMenuItem(value: 'out', child: Text('Se déconnecter'))],
        ),
      ]),
    );
  }
}

class _FriendsTab extends StatefulWidget {
  const _FriendsTab();

  @override
  State<_FriendsTab> createState() => _FriendsTabState();
}

class _FriendsTabState extends State<_FriendsTab> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_query.text.trim().isEmpty) return;
    final social = context.read<SocialService>();
    final msg = await social.addFriend(_query.text);
    if (!mounted) return;
    toast(context, msg ?? social.lastError ?? 'Erreur');
    if (msg != null) _query.clear();
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    return RefreshIndicator(
      onRefresh: social.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          TextField(
            controller: _query,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              hintText: 'Ajouter un ami : pseudo ou code',
              prefixIcon: const Icon(Icons.person_add_alt_1_rounded),
              suffixIcon: IconButton(onPressed: _add, icon: const Icon(Icons.send_rounded)),
            ),
          ),
          if (social.incoming.isNotEmpty) ...[
            const SectionHeader('Demandes reçues'),
            for (final f in social.incoming)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  child: Row(children: [
                    Text(f.other.avatar, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${f.other.label} veut être ton ami', style: context.tt.bodyMedium)),
                    IconButton(onPressed: () => social.removeFriendship(f), icon: const Icon(Icons.close_rounded)),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: () => social.accept(f),
                      child: const Text('Accepter'),
                    ),
                  ]),
                ),
              ),
          ],
          SectionHeader('Mes amis · ${social.friends.length}'),
          if (social.friends.isEmpty)
            AppCard(
              child: Text(
                'Partage ton code ami (en haut) ou ajoute un ami par son pseudo. Vous verrez vos séries respectives.',
                style: context.tt.bodySmall?.copyWith(color: context.subtle),
              ),
            ),
          for (final f in social.friends)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FriendScreen(friendship: f))),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: context.surface2,
                    child: Text(f.other.avatar, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.other.label, style: context.tt.titleSmall),
                      Text('Niv. ${f.other.level} · 🔥 record ${f.other.bestStreak} · ⭐ ${f.other.perfectDays}',
                          style: context.tt.bodySmall?.copyWith(color: context.subtle)),
                    ]),
                  ),
                  Text('${(f.other.avgScore * 100).round()}%', style: context.tt.titleMedium?.copyWith(color: context.cs.primary)),
                  const Icon(Icons.chevron_right_rounded),
                ]),
              ),
            ),
          if (social.outgoing.isNotEmpty) ...[
            const SectionHeader('En attente'),
            for (final f in social.outgoing)
              ListTile(
                leading: Text(f.other.avatar, style: const TextStyle(fontSize: 22)),
                title: Text(f.other.label),
                subtitle: const Text('Demande envoyée'),
                trailing: TextButton(onPressed: () => social.removeFriendship(f), child: const Text('Annuler')),
              ),
          ],
        ],
      ),
    );
  }
}

class _ChallengesTab extends StatefulWidget {
  const _ChallengesTab();

  @override
  State<_ChallengesTab> createState() => _ChallengesTabState();
}

class _ChallengesTabState extends State<_ChallengesTab> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final social = context.read<SocialService>();
    final store = context.read<HabitStore>();
    final c = await social.joinChallenge(_code.text);
    if (!mounted) return;
    if (c == null) {
      toast(context, social.lastError ?? 'Erreur');
      return;
    }
    _code.clear();
    await ensureLocalHabit(store, c);
    if (mounted) toast(context, '⚔️ Tu as rejoint « ${c.name} ». L\'habitude a été ajoutée à ta journée.');
  }

  Future<void> _create() async {
    final store = context.read<HabitStore>();
    final social = context.read<SocialService>();
    final candidates = store.habits.where((h) => h.challengeId == null).toList();
    if (candidates.isEmpty) {
      toast(context, 'Crée d\'abord une habitude à partager.');
      return;
    }
    final h = await showModalBottomSheet<Habit>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Quelle habitude transformer en défi ?', style: ctx.tt.titleMedium),
            ),
            for (final h in candidates)
              ListTile(
                leading: Text(h.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(h.name),
                subtitle: Text(h.frequencyLabel),
                onTap: () => Navigator.pop(ctx, h),
              ),
          ],
        ),
      ),
    );
    if (h == null) return;
    final c = await social.createChallenge(h, h.why);
    if (c == null) {
      if (mounted) toast(context, social.lastError ?? 'Erreur');
      return;
    }
    h.challengeId = c.id;
    await store.updateHabit(h);
    if (mounted) toast(context, 'Défi créé ! Partage le code ${c.inviteCode}');
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    return RefreshIndicator(
      onRefresh: social.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _join(),
                decoration: const InputDecoration(hintText: 'Code d\'un défi', prefixIcon: Icon(Icons.vpn_key_rounded)),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _join, child: const Text('Rejoindre')),
          ]),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Créer un défi à partir d\'une habitude'),
          ),
          SectionHeader('Mes défis · ${social.challenges.length}'),
          if (social.challenges.isEmpty)
            AppCard(
              child: Text(
                'Un défi = une habitude commune. Chacun valide de son côté, le classement montre qui est le plus régulier.',
                style: context.tt.bodySmall?.copyWith(color: context.subtle),
              ),
            ),
          for (final c in social.challenges)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChallengeScreen(challenge: c))),
                gradient: LinearGradient(colors: [
                  Color(c.color).withValues(alpha: 0.22),
                  Color(c.color).withValues(alpha: 0.05),
                ]),
                borderColor: Color(c.color).withValues(alpha: 0.35),
                child: Row(children: [
                  EmojiBadge(c.emoji, color: Color(c.color)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: context.tt.titleMedium),
                      Text('Code ${c.inviteCode}', style: context.tt.bodySmall?.copyWith(color: context.subtle)),
                    ]),
                  ),
                  const Icon(Icons.leaderboard_rounded),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Makes sure a local habit is linked to the challenge (after joining).
Future<void> ensureLocalHabit(HabitStore store, Challenge c) async {
  if (store.data.habits.any((h) => h.challengeId == c.id)) return;
  final all = c.weekdays.toSet().length == 7;
  await store.addHabit(Habit(
    name: c.name,
    emoji: c.emoji,
    color: c.color,
    target: c.target,
    unit: c.unit,
    why: c.description,
    frequency: all ? FrequencyType.daily : FrequencyType.weekdays,
    weekdays: c.weekdays.toSet(),
    challengeId: c.id,
    reminders: [Reminder(hour: 9)],
  ));
}

class _RankingTab extends StatelessWidget {
  const _RankingTab();

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    final people = [
      if (social.me != null) social.me!,
      ...social.friends.map((f) => f.other),
    ]..sort((a, b) {
        final s = b.avgScore.compareTo(a.avgScore);
        return s != 0 ? s : b.xp.compareTo(a.xp);
      });
    return RefreshIndicator(
      onRefresh: social.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Text(
            'Classé par force moyenne des habitudes (régularité récente), puis XP.',
            style: context.tt.bodySmall?.copyWith(color: context.subtle),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < people.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                borderColor: people[i].id == social.me?.id ? context.cs.primary : null,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  SizedBox(
                    width: 34,
                    child: Text(i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}',
                        style: i < 3 ? const TextStyle(fontSize: 24) : context.tt.titleMedium, textAlign: TextAlign.center),
                  ),
                  const SizedBox(width: 8),
                  Text(people[i].avatar, style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(people[i].id == social.me?.id ? '${people[i].label} (toi)' : people[i].label,
                          style: context.tt.titleSmall),
                      const SizedBox(height: 6),
                      GradientBar(value: people[i].avgScore, color: context.cs.primary, height: 6),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${(people[i].avgScore * 100).round()}%', style: context.tt.titleMedium),
                    Text('Niv. ${people[i].level}', style: context.tt.labelSmall?.copyWith(color: context.subtle)),
                  ]),
                ]),
              ).animate().fadeIn(delay: (60 * i).ms).slideX(begin: 0.05),
            ),
        ],
      ),
    );
  }
}
