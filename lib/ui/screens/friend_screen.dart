import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/social.dart';
import '../../services/social_service.dart';
import '../widgets/common.dart';

class FriendScreen extends StatefulWidget {
  const FriendScreen({super.key, required this.friendship});
  final Friendship friendship;

  @override
  State<FriendScreen> createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
  late final Future<List<FriendHabit>> _habits = context.read<SocialService>().friendHabits(widget.friendship.other.id);

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    final f = widget.friendship.other;
    final me = social.me;
    final myChallenges = social.challenges.map((c) => c.id).toSet();

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'remove') {
                await social.removeFriendship(widget.friendship);
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (_) => [const PopupMenuItem(value: 'remove', child: Text('Retirer des amis'))],
          ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            Center(
              child: Column(children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: context.cs.primary.withValues(alpha: 0.18),
                  child: Text(f.avatar, style: const TextStyle(fontSize: 44)),
                ),
                const SizedBox(height: 10),
                Text(f.label, style: context.tt.headlineSmall),
                Text('@${f.username} · Niveau ${f.level}', style: context.tt.bodyMedium?.copyWith(color: context.subtle)),
              ]),
            ),
            if (me != null) ...[
              const SectionHeader('Face à face'),
              AppCard(
                child: Column(children: [
                  Row(children: [
                    Expanded(child: Text('${me.avatar} Toi', style: context.tt.titleSmall)),
                    Expanded(child: Text('${f.label} ${f.avatar}', style: context.tt.titleSmall, textAlign: TextAlign.end)),
                  ]),
                  const SizedBox(height: 12),
                  _VersusRow(label: 'Régularité', mine: me.avgScore, theirs: f.avgScore, format: (v) => '${(v * 100).round()}%'),
                  _VersusRow(label: 'Meilleure série', mine: me.bestStreak.toDouble(), theirs: f.bestStreak.toDouble()),
                  _VersusRow(label: 'Jours parfaits', mine: me.perfectDays.toDouble(), theirs: f.perfectDays.toDouble()),
                  _VersusRow(label: 'XP', mine: me.xp.toDouble(), theirs: f.xp.toDouble()),
                ]),
              ),
            ],
            const SectionHeader('Ses habitudes'),
            FutureBuilder<List<FriendHabit>>(
              future: _habits,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return AppCard(
                    child: Text('Aucune habitude partagée pour l\'instant.',
                        style: context.tt.bodySmall?.copyWith(color: context.subtle)),
                  );
                }
                return Column(children: [
                  for (final h in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        borderColor: h.challengeId != null && myChallenges.contains(h.challengeId)
                            ? AppColors.danger.withValues(alpha: 0.6)
                            : null,
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            EmojiBadge(h.emoji, color: Color(h.color), size: 40, done: h.doneToday),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(h.name, style: context.tt.titleSmall),
                                Text(
                                  '🔥 ${h.currentStreak} · record ${h.bestStreak} · ${(h.rate30 * 100).round()}% sur 30 j'
                                  '${h.challengeId != null && myChallenges.contains(h.challengeId) ? ' · ⚔️ défi commun' : ''}',
                                  style: context.tt.bodySmall?.copyWith(color: context.subtle),
                                ),
                              ]),
                            ),
                            if (h.doneToday) const Pill(icon: '✓', label: 'Aujourd\'hui', color: AppColors.success),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            for (final ch in h.last7.split(''))
                              Expanded(
                                child: Container(
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    color: ch == '1'
                                        ? Color(h.color)
                                        : ch == '0'
                                            ? AppColors.danger.withValues(alpha: 0.25)
                                            : context.cs.onSurface.withValues(alpha: 0.06),
                                  ),
                                ),
                              ),
                          ]),
                        ]),
                      ),
                    ),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _VersusRow extends StatelessWidget {
  const _VersusRow({required this.label, required this.mine, required this.theirs, this.format});
  final String label;
  final double mine, theirs;
  final String Function(double v)? format;

  @override
  Widget build(BuildContext context) {
    final total = mine + theirs;
    final share = total == 0 ? 0.5 : mine / total;
    String fmt(double v) => format?.call(v) ?? v.round().toString();
    final accent = context.cs.primary;
    const other = Color(0xFFFF5C8A);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(children: [
        Row(children: [
          Text(fmt(mine), style: context.tt.titleSmall?.copyWith(color: mine >= theirs ? accent : null)),
          Expanded(child: Text(label, textAlign: TextAlign.center, style: context.tt.labelMedium?.copyWith(color: context.subtle))),
          Text(fmt(theirs), style: context.tt.titleSmall?.copyWith(color: theirs > mine ? other : null)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Row(children: [
              Expanded(flex: (share * 1000).round().clamp(1, 999), child: Container(color: accent)),
              Expanded(flex: ((1 - share) * 1000).round().clamp(1, 999), child: Container(color: other)),
            ]),
          ),
        ),
      ]),
    );
  }
}
