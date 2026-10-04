import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../logic/stats.dart';
import '../../models/habit.dart';
import 'common.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.stats,
    required this.onCheck,
    required this.onOpen,
    this.onLongPress,
    this.haptics = true,
  });

  final Habit habit;
  final HabitStats stats;
  final VoidCallback onCheck;
  final VoidCallback onOpen;
  final VoidCallback? onLongPress;
  final bool haptics;

  @override
  Widget build(BuildContext context) {
    final t = today();
    final done = isDoneOn(habit, t);
    final c = Color(habit.color);
    final count = countOn(habit, t);
    final counter = habit.target > 1;
    final r = BorderRadius.circular(24);

    final subtitle = <InlineSpan>[];
    void add(String s, {Color? color, FontWeight? w}) {
      if (subtitle.isNotEmpty) subtitle.add(TextSpan(text: '  ·  ', style: TextStyle(color: context.faint)));
      subtitle.add(TextSpan(text: s, style: TextStyle(color: color, fontWeight: w)));
    }

    if (stats.currentStreak > 0) {
      add('🔥 ${stats.currentStreak} ${stats.streakUnit}', color: AppColors.flame, w: FontWeight.w700);
    }
    if (habit.frequency == FrequencyType.perWeek) add('${weekCount(habit, t)}/${habit.perWeek} cette sem.');
    if (counter) add('$count/${habit.target} ${habit.unit}'.trim());
    final times = habit.reminders.where((r) => r.enabled).map((r) => hm(r.hour, r.minute)).toList()..sort();
    if (times.isNotEmpty && !done) add('⏰ ${times.first}');
    if (habit.miniDays.contains(dayKey(t))) add('version mini 🤏');
    if (subtitle.isEmpty && habit.cue.isNotEmpty) add(habit.cue);
    if (habit.challengeId != null) add('⚔️ défi');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: r,
        color: done ? null : context.cs.surface,
        gradient: done
            ? LinearGradient(
                colors: [c.withValues(alpha: context.isDark ? 0.26 : 0.16), c.withValues(alpha: context.isDark ? 0.10 : 0.06)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        border: Border.all(color: done ? c.withValues(alpha: 0.45) : context.cs.outline),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: r,
          onTap: onOpen,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                EmojiBadge(habit.emoji, color: c, done: done),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.titleMedium?.copyWith(
                          color: done ? context.cs.onSurface.withValues(alpha: 0.75) : null,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text.rich(
                          TextSpan(children: subtitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.bodySmall?.copyWith(color: context.subtle),
                        ),
                      ],
                      if (counter) ...[
                        const SizedBox(height: 8),
                        GradientBar(value: count / habit.target, color: c, height: 5),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _CheckButton(
                  done: done,
                  color: c,
                  label: counter && !done ? '+1' : null,
                  onTap: () {
                    if (haptics) HapticFeedback.mediumImpact();
                    onCheck();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({required this.done, required this.color, required this.onTap, this.label});
  final bool done;
  final Color color;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done ? habitGradient(color) : null,
        border: done ? null : Border.all(color: color.withValues(alpha: 0.7), width: 2.2),
        boxShadow: done ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: -2)] : null,
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 26)
              .animate(key: const ValueKey('done'))
              .scale(begin: const Offset(0.3, 0.3), duration: 350.ms, curve: Curves.elasticOut)
          : label != null
              ? Text(label!, style: context.tt.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w800))
              : null,
    );
    return Semantics(
      button: true,
      label: done ? 'Annuler' : 'Valider',
      child: GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: Padding(padding: const EdgeInsets.all(4), child: child)),
    );
  }
}
