import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/habit_store.dart';
import '../../models/social.dart';
import '../../services/social_service.dart';
import '../widgets/common.dart';
import 'social_screen.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({super.key, required this.challenge});
  final Challenge challenge;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  late Future<List<LeaderboardEntry>> _board = _load();

  Future<List<LeaderboardEntry>> _load() async {
    final store = context.read<HabitStore>();
    final social = context.read<SocialService>();
    await social.syncStats(store.data); // make sure my latest check-ins are counted
    return social.leaderboard(widget.challenge);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final color = Color(c.color);
    final store = context.watch<HabitStore>();
    final social = context.read<SocialService>();
    final linked = store.data.habits.any((h) => h.challengeId == c.id);

    return Scaffold(
      appBar: AppBar(title: Text(c.name)),
      body: ContentWidth(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() => _board = _load());
            await _board;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            children: [
              AppCard(
                gradient: LinearGradient(colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.06)]),
                borderColor: color.withValues(alpha: 0.4),
                child: Row(children: [
                  EmojiBadge(c.emoji, color: color, size: 58),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.name, style: context.tt.titleLarge),
                      if (c.description.isNotEmpty)
                        Text(c.description, style: context.tt.bodySmall?.copyWith(color: context.subtle)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: c.inviteCode));
                          toast(context, 'Code copié ! Envoie-le à tes amis 📨');
                        },
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Code : ', style: context.tt.bodySmall),
                          Text(c.inviteCode, style: context.tt.titleSmall?.copyWith(letterSpacing: 2)),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, size: 16),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
              if (!linked) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => ensureLocalHabit(store, c),
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Ajouter à mes habitudes'),
                ),
              ],
              const SectionHeader('Classement · 30 derniers jours'),
              FutureBuilder<List<LeaderboardEntry>>(
                future: _board,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return AppCard(child: Text('Impossible de charger le classement : ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
                  }
                  final list = snap.data!;
                  return Column(children: [
                    if (list.length >= 2) _Podium(entries: list.take(3).toList(), color: color),
                    for (var i = 0; i < list.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _EntryTile(rank: i + 1, e: list[i], color: color, isMe: list[i].profile.id == social.me?.id)
                            .animate()
                            .fadeIn(delay: (70 * i).ms)
                            .slideY(begin: 0.1),
                      ),
                  ]);
                },
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  await social.leaveChallenge(c);
                  for (final h in store.data.habits.where((h) => h.challengeId == c.id).toList()) {
                    h.challengeId = null;
                    await store.updateHabit(h);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Quitter le défi (l\'habitude reste)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.color});
  final List<LeaderboardEntry> entries;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final order = [if (entries.length > 1) 1, 0, if (entries.length > 2) 2];
    const heights = [110.0, 80.0, 60.0];
    const medals = ['🥇', '🥈', '🥉'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final i in order)
            Expanded(
              child: Column(children: [
                Text(entries[i].profile.avatar, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 4),
                Text(entries[i].profile.label, style: context.tt.labelLarge, overflow: TextOverflow.ellipsis),
                Text('${(entries[i].rate * 100).round()}%', style: context.tt.labelMedium?.copyWith(color: context.subtle)),
                const SizedBox(height: 6),
                Container(
                  height: heights[i],
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.9 - i * 0.2), color.withValues(alpha: 0.25)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Text(medals[i], style: const TextStyle(fontSize: 26)),
                ).animate().scaleY(begin: 0, alignment: Alignment.bottomCenter, duration: 600.ms, curve: Curves.easeOutBack),
              ]),
            ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.rank, required this.e, required this.color, required this.isMe});
  final int rank;
  final LeaderboardEntry e;
  final Color color;
  final bool isMe;

  @override
  Widget build(BuildContext context) => AppCard(
        borderColor: isMe ? color : null,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(children: [
              SizedBox(width: 28, child: Text('$rank', style: context.tt.titleMedium, textAlign: TextAlign.center)),
              const SizedBox(width: 8),
              Text(e.profile.avatar, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(isMe ? '${e.profile.label} (toi)' : e.profile.label, style: context.tt.titleSmall),
              ),
              if (e.doneToday) const Pill(icon: '✓', label: 'Fait', color: AppColors.success),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${(e.rate * 100).round()}%', style: context.tt.titleMedium?.copyWith(color: color)),
                Text('🔥 ${e.streak}', style: context.tt.labelSmall?.copyWith(color: AppColors.flame)),
              ]),
            ]),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 36),
                for (final d in e.last14)
                  Expanded(
                    child: Container(
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: d == null
                            ? context.cs.onSurface.withValues(alpha: 0.05)
                            : d
                                ? color
                                : AppColors.danger.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
}
