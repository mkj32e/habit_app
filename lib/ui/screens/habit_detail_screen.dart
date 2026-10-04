import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../data/habit_store.dart';
import '../../logic/stats.dart';
import '../../models/habit.dart';
import '../../services/social_service.dart';
import '../widgets/celebration.dart';
import '../widgets/common.dart';
import '../widgets/heatmap.dart';
import 'habit_editor_screen.dart';

class HabitDetailScreen extends StatelessWidget {
  const HabitDetailScreen({super.key, required this.habitId});
  final String habitId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HabitStore>();
    final h = store.byId(habitId);
    if (h == null) return const Scaffold(body: SizedBox());
    final s = store.stats(h);
    final c = Color(h.color);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HabitEditorScreen(habit: h))),
          ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            Row(
              children: [
                EmojiBadge(h.emoji, color: c, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.name, style: context.tt.headlineSmall),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        Pill(label: h.frequencyLabel, color: c),
                        if (h.target > 1) Pill(label: '${h.target} ${h.unit}/jour'.trim(), color: c),
                        if (h.challengeId != null) const Pill(icon: '⚔️', label: 'Défi partagé', color: AppColors.danger),
                        if (h.archived) const Pill(label: 'En pause', color: Colors.grey),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            if (h.identity.isNotEmpty) ...[
              const SizedBox(height: 18),
              AppCard(
                gradient: LinearGradient(colors: [c.withValues(alpha: 0.25), c.withValues(alpha: 0.06)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🪞 Je suis quelqu\'un qui ${h.identity}.', style: context.tt.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      '${s.total} vote${s.total > 1 ? 's' : ''} pour cette identité. Chaque validation en est une preuve.',
                      style: context.tt.bodySmall?.copyWith(color: context.subtle),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            LayoutBuilder(builder: (context, box) {
              final cols = box.maxWidth > 560 ? 4 : 2;
              final w = (box.maxWidth - 10 * (cols - 1)) / cols;
              return Wrap(spacing: 10, runSpacing: 10, children: [
                SizedBox(
                    width: w,
                    child: StatTile(
                        icon: '🔥', value: '${s.currentStreak}', label: 'Série actuelle (${s.streakUnit})', color: AppColors.flame)),
                SizedBox(width: w, child: StatTile(icon: '🏆', value: '${s.bestStreak}', label: 'Record', color: AppColors.gold)),
                SizedBox(
                    width: w,
                    child: StatTile(icon: '💪', value: '${(s.score * 100).round()}%', label: 'Force de l\'habitude', color: c)),
                SizedBox(
                    width: w,
                    child: StatTile(icon: '📅', value: '${(s.rate30 * 100).round()}%', label: 'Régularité 30 j', color: AppColors.success)),
              ]);
            }),
            const SizedBox(height: 10),
            _StrengthExplainer(score: s.score, color: c),
            const SectionHeader('Ne casse pas la chaîne'),
            AppCard(
              child: HabitHeatmap(
                habit: h,
                weeks: MediaQuery.of(context).size.width > 700 ? 26 : 16,
                onDayTap: (d) => _editDay(context, h, d),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('Touche un jour pour corriger l\'historique.',
                  style: context.tt.labelSmall?.copyWith(color: context.faint)),
            ),
            const SectionHeader('12 dernières semaines'),
            AppCard(child: SizedBox(height: 180, child: _WeeklyChart(habit: h))),
            if (h.cue.isNotEmpty || h.location.isNotEmpty || h.miniVersion.isNotEmpty || h.why.isNotEmpty) ...[
              const SectionHeader('Mon plan'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (h.cue.isNotEmpty || h.location.isNotEmpty)
                      _PlanLine('🔗', [
                        if (h.cue.isNotEmpty) h.cue,
                        'je fais « ${h.name.toLowerCase()} »',
                        if (h.location.isNotEmpty) '(${h.location})',
                      ].join(', ')),
                    if (h.miniVersion.isNotEmpty) _PlanLine('🤏', 'Les jours difficiles : ${h.miniVersion}'),
                    if (h.why.isNotEmpty) _PlanLine('❤️', h.why),
                  ],
                ),
              ),
            ],
            const SectionHeader('Multijoueur'),
            _ChallengeTile(habit: h),
            if (h.notes.isNotEmpty) ...[
              const SectionHeader('Notes'),
              AppCard(child: Text(h.notes)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editDay(BuildContext context, Habit h, DateTime d) async {
    final store = context.read<HabitStore>();
    final done = isDoneOn(h, d);
    final frozen = h.frozenDays.contains(dayKey(d));
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(DateFormat('EEEE d MMMM', 'fr_FR').format(d), style: ctx.tt.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(done ? Icons.close_rounded : Icons.check_rounded),
              title: Text(done ? 'Marquer comme non fait' : 'Marquer comme fait'),
              onTap: () async {
                Navigator.pop(ctx);
                final r = await store.toggle(h, d);
                if (context.mounted) await celebrate(context, h, r);
              },
            ),
            if (!done && h.miniVersion.isNotEmpty)
              ListTile(
                leading: const Text('🤏', style: TextStyle(fontSize: 20)),
                title: const Text('Fait en version mini'),
                onTap: () {
                  Navigator.pop(ctx);
                  store.markMini(h, d);
                },
              ),
            if (!done && !frozen && d != today())
              ListTile(
                leading: const Text('🧊', style: TextStyle(fontSize: 20)),
                title: Text('Utiliser un gel de série (${store.global.freezesAvailable} dispo.)'),
                enabled: store.global.freezesAvailable > 0,
                onTap: () {
                  Navigator.pop(ctx);
                  store.useFreeze(h, d);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _PlanLine extends StatelessWidget {
  const _PlanLine(this.icon, this.text);
  final String icon, text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: context.tt.bodyMedium)),
        ]),
      );
}

class _StrengthExplainer extends StatelessWidget {
  const _StrengthExplainer({required this.score, required this.color});
  final double score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = score < 0.25
        ? 'Fragile — chaque répétition compte double maintenant.'
        : score < 0.5
            ? 'En construction — le circuit se forme.'
            : score < 0.8
                ? 'Solide — tu peux rater un jour sans tout perdre.'
                : 'Ancrée — c\'est devenu une partie de toi.';
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Force de l\'habitude', style: context.tt.titleSmall),
            const Spacer(),
            Text('${(score * 100).round()}%', style: context.tt.titleSmall?.copyWith(color: color)),
          ]),
          const SizedBox(height: 10),
          GradientBar(value: score, color: color, height: 10),
          const SizedBox(height: 8),
          Text(label, style: context.tt.bodySmall?.copyWith(color: context.subtle)),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final t = today();
    final start = addDays(weekStart(t), -7 * 11);
    final c = Color(habit.color);
    final values = <double>[];
    for (var w = 0; w < 12; w++) {
      final ws = addDays(start, 7 * w);
      var done = 0, sched = 0;
      for (var i = 0; i < 7; i++) {
        final d = addDays(ws, i);
        if (d.isAfter(t)) break;
        if (isScheduledOn(habit, d)) sched++;
        if (isCoveredOn(habit, d)) done++;
      }
      final goal = habit.frequency == FrequencyType.perWeek ? habit.perWeek : max(1, sched);
      values.add(sched == 0 && habit.frequency != FrequencyType.perWeek ? 0 : min(1, done / goal));
    }
    return BarChart(
      BarChartData(
        maxY: 1,
        minY: 0,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 0.5,
          getDrawingHorizontalLine: (_) => FlLine(color: context.cs.outline, strokeWidth: 1, dashArray: [4, 4]),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 0.5,
              getTitlesWidget: (v, _) =>
                  Text('${(v * 100).round()}%', style: context.tt.labelSmall?.copyWith(color: context.faint)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i % 3 != 2) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('d/M').format(addDays(start, 7 * i)),
                      style: context.tt.labelSmall?.copyWith(color: context.faint)),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (g, _, rod, _) => BarTooltipItem(
              '${(rod.toY * 100).round()}%',
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: values[i],
                width: 14,
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                  colors: [c.withValues(alpha: 0.55), c],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: 1, color: c.withValues(alpha: 0.07)),
              ),
            ]),
        ],
      ),
      duration: const Duration(milliseconds: 600),
    );
  }
}

class _ChallengeTile extends StatelessWidget {
  const _ChallengeTile({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    final store = context.read<HabitStore>();
    if (!social.signedIn) {
      return AppCard(
        child: Text(
          'Connecte-toi dans l\'onglet Amis pour transformer cette habitude en défi et la comparer avec tes amis.',
          style: context.tt.bodySmall?.copyWith(color: context.subtle),
        ),
      );
    }
    final existing = social.challenges.where((c) => c.id == habit.challengeId).firstOrNull;
    if (existing != null) {
      return AppCard(
        child: Row(children: [
          const Text('⚔️', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Défi : ${existing.name}', style: context.tt.titleSmall),
              Text('Code d\'invitation : ${existing.inviteCode}', style: context.tt.bodySmall?.copyWith(color: context.subtle)),
            ]),
          ),
          IconButton(
            tooltip: 'Copier le code',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: existing.inviteCode));
              toast(context, 'Code copié ! Envoie-le à tes amis 📨');
            },
          ),
        ]),
      );
    }
    return AppCard(
      onTap: () async {
        final ch = await social.createChallenge(habit, habit.why);
        if (ch == null) {
          if (context.mounted) toast(context, social.lastError ?? 'Erreur');
          return;
        }
        habit.challengeId = ch.id;
        await store.updateHabit(habit);
        if (context.mounted) toast(context, 'Défi créé ! Code : ${ch.inviteCode}');
      },
      child: Row(children: [
        const Text('⚔️', style: TextStyle(fontSize: 24)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Lancer un défi avec mes amis', style: context.tt.titleSmall),
            Text('Partage un code : vous suivez la même habitude et un classement montre qui est le plus régulier.',
                style: context.tt.bodySmall?.copyWith(color: context.subtle)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded),
      ]),
    );
  }
}
