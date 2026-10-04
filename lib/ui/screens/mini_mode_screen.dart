import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../data/habit_store.dart';
import '../../logic/stats.dart';
import '../../services/desktop_service.dart';
import '../widgets/celebration.dart';
import '../widgets/common.dart';

/// Compact always-on-top window for Windows: the desktop "widget".
class MiniModeScreen extends StatelessWidget {
  const MiniModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HabitStore>();
    final desktop = context.read<DesktopService>();
    final t = today();
    final due = store.dueToday..sort((a, b) => (isDoneOn(a, t) ? 1 : 0).compareTo(isDoneOn(b, t) ? 1 : 0));
    final g = store.global;
    final pct = g.todayTotal == 0 ? 0.0 : g.todayDone / g.todayTotal;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          border: Border.all(color: context.cs.primary.withValues(alpha: 0.4)),
          gradient: LinearGradient(
            colors: [context.cs.primary.withValues(alpha: 0.16), context.theme.scaffoldBackgroundColor],
            begin: Alignment.topCenter,
            end: Alignment.center,
          ),
        ),
        child: Column(
          children: [
            DragToMoveArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
                child: Row(children: [
                  ProgressRing(
                    value: pct,
                    size: 44,
                    stroke: 5,
                    color: context.cs.primary,
                    child: Text('${g.todayDone}/${g.todayTotal}', style: context.tt.labelSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Aujourd\'hui', style: context.tt.titleSmall),
                      Text(prettyDate(t), style: context.tt.labelSmall?.copyWith(color: context.subtle)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Agrandir',
                    visualDensity: VisualDensity.compact,
                    onPressed: desktop.exitMini,
                    icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  ),
                ]),
              ),
            ),
            Expanded(
              child: due.isEmpty
                  ? Center(child: Text('Rien de prévu 🎉', style: context.tt.bodyMedium?.copyWith(color: context.subtle)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      itemCount: due.length,
                      itemBuilder: (context, i) {
                        final h = due[i];
                        final done = isDoneOn(h, t);
                        final c = Color(h.color);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: done ? c.withValues(alpha: 0.16) : context.cs.surface,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                final r = h.target > 1 && !done ? await store.increment(h) : await store.toggle(h);
                                if (context.mounted) await celebrate(context, h, r);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                child: Row(children: [
                                  Text(h.emoji, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      h.target > 1 ? '${h.name}  ${countOn(h, t)}/${h.target}' : h.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.tt.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: done ? context.subtle : null,
                                        decoration: done ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: done ? c : null,
                                      border: done ? null : Border.all(color: c, width: 2),
                                    ),
                                    child: done ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
