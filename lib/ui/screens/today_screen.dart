import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../data/habit_store.dart';
import '../../logic/messages.dart';
import '../../logic/stats.dart';
import '../../models/habit.dart';
import '../widgets/celebration.dart';
import '../widgets/common.dart';
import '../widgets/habit_card.dart';
import 'habit_detail_screen.dart';
import 'habit_editor_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HabitStore>();
    final t = today();
    final due = store.dueToday;
    final todo = due.where((h) => !isDoneOn(h, t)).toList();
    final done = due.where((h) => isDoneOn(h, t)).toList();
    final missed = store.habits.where((h) => store.stats(h).missedYesterday && !isDoneOn(h, t)).toList();
    final notToday = store.habits.where((h) => !due.contains(h)).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle habitude', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverList.list(children: [
                  _Header(store: store),
                  const SizedBox(height: 18),
                  _HeroCard(store: store).animate().fadeIn(duration: 400.ms).slideY(begin: 0.06),
                  for (final h in missed) _NeverMissTwice(habit: h),
                  if (store.habits.isEmpty)
                    EmptyState(
                      emoji: '🌱',
                      title: 'Ton premier rituel',
                      message:
                          'Commence petit : une seule habitude, si facile que tu ne peux pas dire non. On construit le reste ensemble.',
                      action: FilledButton.icon(
                        onPressed: () => openEditor(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Créer une habitude'),
                      ),
                    ),
                  if (todo.isNotEmpty) SectionHeader('À faire · ${todo.length}'),
                ]),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: todo.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _card(context, store, todo[i])
                      .animate()
                      .fadeIn(delay: (40 * i).ms, duration: 300.ms)
                      .slideX(begin: 0.04),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.list(children: [
                  if (todo.isEmpty && done.isNotEmpty) const _AllDone(),
                  if (done.isNotEmpty) SectionHeader('Fait · ${done.length}'),
                ]),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(
                  itemCount: done.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _card(context, store, done[i]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                sliver: SliverList.list(children: [
                  const _PrincipleCard(),
                  if (notToday.isNotEmpty) ...[
                    const SectionHeader('Pas prévu aujourd\'hui'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final h in notToday)
                          ActionChip(
                            avatar: Text(h.emoji),
                            label: Text(h.name),
                            onPressed: () => openDetail(context, h),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 110),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, HabitStore store, Habit h) => HabitCard(
        key: ValueKey(h.id),
        habit: h,
        stats: store.stats(h),
        haptics: store.settings.haptics,
        onOpen: () => openDetail(context, h),
        onLongPress: () => showQuickActions(context, h),
        onCheck: () async {
          final r = h.target > 1 && !isDoneOn(h, today()) ? await store.increment(h) : await store.toggle(h);
          if (context.mounted) await celebrate(context, h, r);
        },
      );
}

void openEditor(BuildContext context, [Habit? h]) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HabitEditorScreen(habit: h)));

void openDetail(BuildContext context, Habit h) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: h.id)));

Future<void> showQuickActions(BuildContext context, Habit h) async {
  final store = context.read<HabitStore>();
  final t = today();
  final done = isDoneOn(h, t);
  await showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: EmojiBadge(h.emoji, color: Color(h.color), size: 40),
              title: Text(h.name, style: ctx.tt.titleMedium),
              subtitle: Text(h.frequencyLabel),
            ),
            const Divider(),
            if (!done && h.miniVersion.isNotEmpty)
              ListTile(
                leading: const Text('🤏', style: TextStyle(fontSize: 22)),
                title: const Text('Valider la version mini'),
                subtitle: Text(h.miniVersion),
                onTap: () async {
                  Navigator.pop(ctx);
                  final r = await store.markMini(h);
                  if (context.mounted) await celebrate(context, h, r);
                },
              ),
            if (h.target > 1 && countOn(h, t) > 0)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline_rounded),
                title: const Text('Retirer 1'),
                onTap: () {
                  Navigator.pop(ctx);
                  store.increment(h, by: -1);
                },
              ),
            ListTile(
              leading: Icon(done ? Icons.undo_rounded : Icons.check_circle_outline_rounded),
              title: Text(done ? 'Marquer comme non fait' : 'Marquer comme fait'),
              onTap: () async {
                Navigator.pop(ctx);
                final r = await store.toggle(h);
                if (context.mounted) await celebrate(context, h, r);
              },
            ),
            ListTile(
              leading: const Icon(Icons.insights_rounded),
              title: const Text('Statistiques'),
              onTap: () {
                Navigator.pop(ctx);
                openDetail(context, h);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(ctx);
                openEditor(context, h);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.store});
  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    final level = store.global.level;
    final name = store.settings.userName;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prettyDate(DateTime.now()), style: context.tt.labelLarge?.copyWith(color: context.subtle)),
              const SizedBox(height: 2),
              Text(
                name.isEmpty ? '${greeting()} 👋' : '${greeting()}, $name 👋',
                style: context.tt.headlineMedium,
              ),
            ],
          ),
        ),
        Tooltip(
          message: '${level.xpInLevel}/${level.xpForNext} XP',
          child: ProgressRing(
            value: level.progress,
            size: 54,
            stroke: 5,
            color: context.cs.primary,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${level.number}', style: context.tt.titleMedium?.copyWith(height: 1, fontWeight: FontWeight.w800)),
                Text('NIV', style: context.tt.labelSmall?.copyWith(fontSize: 8, color: context.subtle, height: 1)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.store});
  final HabitStore store;

  @override
  Widget build(BuildContext context) {
    final g = store.global;
    final total = g.todayTotal;
    final pct = total == 0 ? 0.0 : g.todayDone / total;
    final accent = context.cs.primary;
    final msg = total == 0
        ? 'Rien de prévu aujourd\'hui. Profite !'
        : pct >= 1
            ? 'Journée parfaite. Tu es inarrêtable.'
            : pct >= 0.5
                ? 'Plus que ${total - g.todayDone}. Tu tiens le bon bout !'
                : g.todayDone == 0
                    ? 'Une seule action pour lancer la journée.'
                    : 'Bon début, garde l\'élan !';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: context.isDark ? 0.32 : 0.18),
            const Color(0xFFFF5C8A).withValues(alpha: context.isDark ? 0.16 : 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          ProgressRing(
            value: pct,
            size: 108,
            stroke: 11,
            color: accent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(pct * 100).round()}%', style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                Text('${g.todayDone}/$total', style: context.tt.labelMedium?.copyWith(color: context.subtle)),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg, style: context.tt.titleMedium),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (g.perfectStreak > 0) Pill(icon: '⭐', label: '${g.perfectStreak} j parfaits', color: AppColors.gold),
                    Pill(icon: '🧊', label: '${g.freezesAvailable} gel${g.freezesAvailable > 1 ? 's' : ''}', color: AppColors.ice),
                    Pill(icon: '⚡', label: '${g.xp} XP', color: accent),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NeverMissTwice extends StatelessWidget {
  const _NeverMissTwice({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final store = context.read<HabitStore>();
    final freezes = store.global.freezesAvailable;
    final yesterday = addDays(today(), -1);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppCard(
        borderColor: AppColors.flame.withValues(alpha: 0.5),
        color: AppColors.flame.withValues(alpha: context.isDark ? 0.10 : 0.07),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(habit.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(child: Text('Ne rate jamais deux fois', style: context.tt.titleSmall)),
            ]),
            const SizedBox(height: 6),
            Text(
              '« ${habit.name} » a été raté hier. Une fois, c\'est un accident ; deux fois, c\'est le début d\'une habitude. '
              '${habit.miniVersion.isNotEmpty ? 'Même la version mini compte : ${habit.miniVersion}' : 'Fais-le aujourd\'hui, même en version réduite.'}',
              style: context.tt.bodySmall?.copyWith(color: context.subtle),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                if (freezes > 0)
                  TextButton.icon(
                    onPressed: () {
                      if (store.useFreeze(habit, yesterday)) toast(context, '🧊 Série protégée ! Il te reste ${freezes - 1} gel(s).');
                    },
                    icon: const Text('🧊'),
                    label: Text('Protéger ma série ($freezes)'),
                  ),
                if (habit.miniVersion.isNotEmpty)
                  TextButton.icon(
                    onPressed: () async {
                      final r = await store.markMini(habit);
                      if (context.mounted) await celebrate(context, habit, r);
                    },
                    icon: const Text('🤏'),
                    label: const Text('Version mini'),
                  ),
              ],
            ),
          ],
        ),
      ).animate().shakeX(hz: 3, amount: 2, duration: 500.ms),
    );
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: AppCard(
          gradient: LinearGradient(colors: [
            AppColors.success.withValues(alpha: 0.25),
            AppColors.success.withValues(alpha: 0.05),
          ]),
          child: Row(children: [
            const Text('🏆', style: TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Tout est fait !', style: context.tt.titleMedium),
                Text('Prends un instant pour savourer. Tu as tenu parole envers toi-même.',
                    style: context.tt.bodySmall?.copyWith(color: context.subtle)),
              ]),
            ),
          ]),
        ).animate().scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack),
      );
}

class _PrincipleCard extends StatelessWidget {
  const _PrincipleCard();

  @override
  Widget build(BuildContext context) {
    final (title, body) = principleOfTheDay();
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
              child: const Text('💡', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PRINCIPE DU JOUR', style: context.tt.labelSmall?.copyWith(color: AppColors.gold, letterSpacing: 1.4)),
                  const SizedBox(height: 4),
                  Text(title, style: context.tt.titleSmall),
                  const SizedBox(height: 4),
                  Text(body, style: context.tt.bodySmall?.copyWith(color: context.subtle, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
