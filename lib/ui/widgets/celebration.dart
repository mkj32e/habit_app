import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../data/habit_store.dart';
import '../../logic/gamification.dart';
import '../../logic/messages.dart';
import '../../models/habit.dart';
import 'common.dart';

/// Owns the confetti cannon displayed above the whole app.
class CelebrationController {
  final confetti = ConfettiController(duration: const Duration(milliseconds: 1400));
  void fire() => confetti.play();
  void dispose() => confetti.dispose();
}

class ConfettiLayer extends StatelessWidget {
  const ConfettiLayer({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.read<CelebrationController>();
    return Stack(
      children: [
        child,
        Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: ConfettiWidget(
              confettiController: c.confetti,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.06,
              numberOfParticles: 26,
              maxBlastForce: 32,
              minBlastForce: 10,
              gravity: 0.22,
              colors: const [
                Color(0xFF7C5CFF),
                Color(0xFFFF5C8A),
                Color(0xFF34D399),
                Color(0xFFFFC94D),
                Color(0xFF38BDF8),
              ],
              createParticlePath: _star,
            ),
          ),
        ),
      ],
    );
  }

  static Path _star(Size size) {
    final path = Path();
    final rnd = Random();
    if (rnd.nextBool()) {
      path.addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 10, 6), const Radius.circular(2)));
      return path;
    }
    const n = 5;
    const outer = 6.0, inner = 2.6;
    for (var i = 0; i < n * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = pi / n * i - pi / 2;
      final p = Offset(r * cos(a), r * sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }
}

/// Positive reinforcement after a completion: variable reward message,
/// confetti on milestones and badge unlock dialogs.
Future<void> celebrate(BuildContext context, Habit h, CompletionResult r) async {
  if (!r.becameDone) return;
  final store = context.read<HabitStore>();
  final s = store.stats(h);
  final milestone = s.currentStreak > 0 && (s.currentStreak % 7 == 0 || [3, 21, 30, 66, 100].contains(s.currentStreak));
  if (store.settings.celebrations && (r.perfectDay || milestone || r.newBadges.isNotEmpty)) {
    context.read<CelebrationController>().fire();
  }
  if (store.settings.haptics) HapticFeedback.heavyImpact();

  String msg;
  if (r.perfectDay) {
    msg = randomOf(kPerfectDayMessages);
  } else if (milestone) {
    msg = '${h.emoji} ${s.currentStreak} ${s.streakUnit} d\'affilée ! Palier atteint 🏅';
  } else {
    msg = randomOf(kRewardMessages);
  }
  toast(context, '+${h.miniDays.contains(dayKey(today())) ? 5 : 10} XP · $msg');

  for (final b in r.newBadges) {
    if (!context.mounted) return;
    await showBadgeDialog(context, b);
  }
}

Future<void> showBadgeDialog(BuildContext context, Achievement b) => showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('NOUVEAU BADGE', style: ctx.tt.labelMedium?.copyWith(color: ctx.cs.primary, letterSpacing: 2)),
              const SizedBox(height: 18),
              Container(
                width: 110,
                height: 110,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: accentGradient(ctx.cs.primary),
                  boxShadow: [BoxShadow(color: ctx.cs.primary.withValues(alpha: 0.5), blurRadius: 40)],
                ),
                child: Text(b.emoji, style: const TextStyle(fontSize: 54)),
              )
                  .animate()
                  .scale(begin: const Offset(0.2, 0.2), duration: 600.ms, curve: Curves.elasticOut)
                  .then()
                  .shimmer(duration: 1200.ms),
              const SizedBox(height: 18),
              Text(b.title, style: ctx.tt.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(b.description, style: ctx.tt.bodyMedium?.copyWith(color: ctx.subtle), textAlign: TextAlign.center),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Génial !')),
              ),
            ],
          ),
        ),
      ),
    );
