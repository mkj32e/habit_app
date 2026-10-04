import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../data/habit_store.dart';
import '../../logic/gamification.dart';
import '../../logic/stats.dart';
import '../../models/habit.dart';
import '../widgets/celebration.dart';
import '../widgets/common.dart';
import 'today_screen.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HabitStore>();
    final g = store.global;
    final level = g.level;
    final accent = context.cs.primary;
    final ranked = [...store.habits]..sort((a, b) => store.stats(b).score.compareTo(store.stats(a).score));
    final ctx = store.badgeContext;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              Text('Progrès', style: context.tt.headlineMedium),
              const SizedBox(height: 16),
              // Level card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: accentGradient(accent),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 12))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('NIVEAU ${level.number}',
                          style: context.tt.labelLarge?.copyWith(color: Colors.white70, letterSpacing: 2)),
                      const Spacer(),
                      Text('${g.xp} XP', style: context.tt.labelLarge?.copyWith(color: Colors.white)),
                    ]),
                    const SizedBox(height: 4),
                    Text(level.title, style: context.tt.headlineMedium?.copyWith(color: Colors.white)),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: level.progress,
                        minHeight: 10,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${level.xpForNext - level.xpInLevel} XP avant le niveau ${level.number + 1}',
                        style: context.tt.bodySmall?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, box) {
                final cols = box.maxWidth > 560 ? 4 : 2;
                final w = (box.maxWidth - 10 * (cols - 1)) / cols;
                return Wrap(spacing: 10, runSpacing: 10, children: [
                  SizedBox(width: w, child: StatTile(icon: '⭐', value: '${g.perfectDays}', label: 'Journées parfaites')),
                  SizedBox(width: w, child: StatTile(icon: '✅', value: '${g.totalCompletions}', label: 'Validations')),
                  SizedBox(width: w, child: StatTile(icon: '🏆', value: '${g.bestStreak}', label: 'Meilleure série')),
                  SizedBox(width: w, child: StatTile(icon: '🧊', value: '${g.freezesAvailable}', label: 'Gels de série')),
                ]);
              }),
              const SectionHeader('30 derniers jours'),
              AppCard(child: SizedBox(height: 190, child: _DailyChart(habits: store.habits))),
              if (ranked.isNotEmpty) ...[
                const SectionHeader('Force de chaque habitude'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      for (final h in ranked)
                        InkWell(
                          onTap: () => openDetail(context, h),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(children: [
                              Text(h.emoji, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Expanded(child: Text(h.name, style: context.tt.titleSmall, overflow: TextOverflow.ellipsis)),
                                    Text('🔥 ${store.stats(h).currentStreak}',
                                        style: context.tt.labelMedium?.copyWith(color: AppColors.flame)),
                                    const SizedBox(width: 10),
                                    Text('${(store.stats(h).score * 100).round()}%', style: context.tt.labelLarge),
                                  ]),
                                  const SizedBox(height: 6),
                                  GradientBar(value: store.stats(h).score, color: Color(h.color), height: 6),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              SectionHeader('Badges · ${kBadges.where((b) => b.unlocked(g, ctx)).length}/${kBadges.length}'),
              LayoutBuilder(builder: (context, box) {
                final cols = max(3, (box.maxWidth / 120).floor());
                final w = (box.maxWidth - 10 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final b in kBadges)
                      SizedBox(width: w, child: _BadgeTile(badge: b, unlocked: b.unlocked(g, ctx))),
                  ],
                );
              }),
              if (store.archivedHabits.isNotEmpty) ...[
                const SectionHeader('En pause'),
                for (final h in store.archivedHabits)
                  ListTile(
                    leading: Text(h.emoji, style: const TextStyle(fontSize: 22)),
                    title: Text(h.name),
                    trailing: TextButton(onPressed: () => store.setArchived(h, false), child: const Text('Réactiver')),
                    onTap: () => openDetail(context, h),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.unlocked});
  final Achievement badge;
  final bool unlocked;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        onTap: unlocked ? () => showBadgeDialog(context, badge) : () => toast(context, '🔒 ${badge.description}'),
        child: Column(
          children: [
            Opacity(
              opacity: unlocked ? 1 : 0.25,
              child: ColorFiltered(
                colorFilter: unlocked
                    ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                    : const ColorFilter.matrix([
                        0.33, 0.33, 0.33, 0, 0, //
                        0.33, 0.33, 0.33, 0, 0, //
                        0.33, 0.33, 0.33, 0, 0, //
                        0, 0, 0, 1, 0,
                      ]),
                child: Text(badge.emoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: context.tt.labelMedium?.copyWith(color: unlocked ? null : context.faint),
            ),
          ],
        ),
      );
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.habits});
  final List<Habit> habits;

  @override
  Widget build(BuildContext context) {
    final t = today();
    final accent = context.cs.primary;
    final spots = <FlSpot>[];
    for (var i = 29; i >= 0; i--) {
      final d = addDays(t, -i);
      final due = habits.where((h) =>
          !d.isBefore(dateOnly(h.createdAt)) && isScheduledOn(h, d) && h.frequency != FrequencyType.perWeek);
      final n = due.length;
      final done = due.where((h) => isCoveredOn(h, d)).length;
      spots.add(FlSpot((29 - i).toDouble(), n == 0 ? 0 : done / n));
    }
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 1.05,
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
              getTitlesWidget: (v, _) => v > 1
                  ? const SizedBox()
                  : Text('${(v * 100).round()}%', style: context.tt.labelSmall?.copyWith(color: context.faint)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              // One label per week, aligned on today (fl_chart also asks for min/max).
              getTitlesWidget: (v, _) => (29 - v.toInt()) % 7 != 0 || v != v.roundToDouble()
                  ? const SizedBox()
                  : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(DateFormat('d/M').format(addDays(t, v.toInt() - 29)),
                    style: context.tt.labelSmall?.copyWith(color: context.faint)),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem('${(s.y * 100).round()}%', const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            preventCurveOverShooting: true,
            barWidth: 3.5,
            gradient: accentGradient(accent),
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.35), accent.withValues(alpha: 0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
