import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../logic/stats.dart';
import '../../models/habit.dart';

/// "Don't break the chain" calendar: one column per week, one row per weekday.
class HabitHeatmap extends StatelessWidget {
  const HabitHeatmap({super.key, required this.habit, this.weeks = 18, this.onDayTap});

  final Habit habit;
  final int weeks;
  final void Function(DateTime day)? onDayTap;

  @override
  Widget build(BuildContext context) {
    final t = today();
    final firstWeek = addDays(weekStart(t), -7 * (weeks - 1));
    final c = Color(habit.color);
    final created = dateOnly(habit.createdAt);

    return LayoutBuilder(builder: (context, box) {
      const gap = 4.0;
      const labelW = 16.0;
      final cell = ((box.maxWidth - labelW - gap * weeks) / weeks).clamp(8.0, 26.0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month labels
          Padding(
            padding: const EdgeInsets.only(left: labelW + gap),
            child: SizedBox(
              height: 16,
              child: Stack(
                children: [
                  for (var w = 0; w < weeks; w++)
                    if (_monthStarts(addDays(firstWeek, 7 * w)))
                      Positioned(
                        left: w * (cell + gap),
                        child: Text(
                          DateFormat('MMM', 'fr_FR').format(addDays(firstWeek, 7 * w + 6)),
                          style: context.tt.labelSmall?.copyWith(color: context.faint),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  for (var d = 0; d < 7; d++)
                    SizedBox(
                      width: labelW,
                      height: cell + gap,
                      child: d.isEven
                          ? Text(weekdayShort[d], style: context.tt.labelSmall?.copyWith(color: context.faint, fontSize: 10))
                          : null,
                    ),
                ],
              ),
              const SizedBox(width: gap),
              for (var w = 0; w < weeks; w++)
                Padding(
                  padding: const EdgeInsets.only(right: gap),
                  child: Column(
                    children: [
                      for (var d = 0; d < 7; d++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: gap),
                          child: _cell(context, addDays(firstWeek, 7 * w + d), t, created, c, cell),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _legend(context, c.withValues(alpha: 1), 'Fait'),
              _legend(context, c.withValues(alpha: 0.45), 'Mini'),
              _legend(context, AppColors.ice, 'Gel'),
              _legend(context, AppColors.danger.withValues(alpha: 0.35), 'Raté'),
            ],
          ),
        ],
      );
    });
  }

  bool _monthStarts(DateTime weekMonday) {
    for (var i = 0; i < 7; i++) {
      if (addDays(weekMonday, i).day == 1) return true;
    }
    return false;
  }

  Widget _legend(BuildContext context, Color c, String label) => Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(label, style: context.tt.labelSmall?.copyWith(color: context.subtle)),
        ]),
      );

  Widget _cell(BuildContext context, DateTime d, DateTime t, DateTime created, Color c, double size) {
    final future = d.isAfter(t);
    final k = dayKey(d);
    Color color;
    if (future) {
      color = Colors.transparent;
    } else if (habit.miniDays.contains(k)) {
      color = c.withValues(alpha: 0.45);
    } else if (isDoneOn(habit, d)) {
      color = c;
    } else if (habit.frozenDays.contains(k)) {
      color = AppColors.ice;
    } else if ((habit.log[k] ?? 0) > 0) {
      color = c.withValues(alpha: 0.2 + 0.5 * (habit.log[k]! / habit.target));
    } else if (!d.isBefore(created) && d != t && isScheduledOn(habit, d) && habit.frequency != FrequencyType.perWeek) {
      color = AppColors.danger.withValues(alpha: 0.22);
    } else {
      color = context.cs.onSurface.withValues(alpha: 0.06);
    }
    final isToday = d == t;
    return GestureDetector(
      onTap: future || onDayTap == null ? null : () => onDayTap!(d),
      child: Tooltip(
        message: DateFormat('EEE d MMM', 'fr_FR').format(d),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(size * 0.28),
            border: isToday ? Border.all(color: context.cs.onSurface.withValues(alpha: 0.7), width: 1.5) : null,
          ),
        ),
      ),
    );
  }
}
