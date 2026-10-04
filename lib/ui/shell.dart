import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../services/desktop_service.dart';
import '../services/social_service.dart';
import 'screens/mini_mode_screen.dart';
import 'screens/progress_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/social_screen.dart';
import 'screens/today_screen.dart';

/// Bottom navigation on phones, navigation rail on wide windows.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;

  static const _pages = [TodayScreen(), ProgressScreen(), SocialScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final desktop = context.watch<DesktopService>();
    if (desktop.mini) return const MiniModeScreen();

    final requests = context.select<SocialService, int>((s) => s.incoming.length);
    final wide = MediaQuery.of(context).size.width >= 840;
    final destinations = [
      (Icons.wb_sunny_outlined, Icons.wb_sunny_rounded, 'Aujourd\'hui', 0),
      (Icons.insights_outlined, Icons.insights_rounded, 'Progrès', 0),
      (Icons.people_alt_outlined, Icons.people_alt_rounded, 'Amis', requests),
      (Icons.tune_outlined, Icons.tune_rounded, 'Réglages', 0),
    ];

    Widget icon(IconData i, int badge) => badge > 0 ? Badge(label: Text('$badge'), child: Icon(i)) : Icon(i);

    final page = IndexedStack(index: _index, children: _pages);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.of(context).size.width >= 1100,
              minExtendedWidth: 210,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(8, 20, 8, 28),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(gradient: accentGradient(context.cs.primary), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.check_rounded, color: Colors.white),
                  ),
                  if (MediaQuery.of(context).size.width >= 1100) ...[
                    const SizedBox(width: 10),
                    Text('Rituel', style: context.tt.titleLarge),
                  ],
                ]),
              ),
              trailing: desktop.mini || !DesktopService.supported
                  ? null
                  : Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: IconButton(
                            tooltip: 'Mini-widget',
                            onPressed: () => desktop.enterMini(),
                            icon: const Icon(Icons.picture_in_picture_alt_rounded),
                          ),
                        ),
                      ),
                    ),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(icon: icon(d.$1, d.$4), selectedIcon: icon(d.$2, d.$4), label: Text(d.$3)),
              ],
            ),
            VerticalDivider(width: 1, color: context.cs.outline),
            Expanded(child: page),
          ],
        ),
      );
    }

    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: icon(d.$1, d.$4), selectedIcon: icon(d.$2, d.$4), label: d.$3),
        ],
      ),
    );
  }
}
