import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/habit_store.dart';
import '../../services/notification_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  final _name = TextEditingController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_index < 2) {
      await _page.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
      return;
    }
    await NotificationService.requestPermissions();
    if (!mounted) return;
    await context.read<HabitStore>().updateSettings((s) {
      s.userName = _name.text.trim();
      s.onboardingDone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.cs.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _page,
                    onPageChanged: (i) => setState(() => _index = i),
                    children: [
                      _Page(
                        hero: '🌱',
                        title: 'Bienvenue dans Rituel',
                        text: 'Les grandes transformations sont faites de petites actions répétées. On va construire les tiennes, une à la fois.',
                        child: TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textAlign: TextAlign.center,
                          style: context.tt.titleLarge,
                          decoration: const InputDecoration(hintText: 'Ton prénom'),
                        ),
                      ),
                      const _Page(
                        hero: '🧠',
                        title: 'La science des habitudes',
                        text: 'Rituel s\'appuie sur ce qui marche vraiment :',
                        child: Column(children: [
                          _Bullet('🪞', 'Identité', 'Deviens la personne qui fait, pas seulement celle qui veut.'),
                          _Bullet('🔗', 'Déclencheurs', '« Après mon café, je médite » : ancre le nouveau dans l\'existant.'),
                          _Bullet('🤏', 'Règle des 2 minutes', 'Les jours sans, une version mini garde la série.'),
                          _Bullet('🔥', 'Séries & gels', 'Ne casse pas la chaîne… et ne rate jamais deux fois.'),
                          _Bullet('🤝', 'Entre amis', 'Défis communs et classements pour se tirer vers le haut.'),
                        ]),
                      ),
                      const _Page(
                        hero: '🔔',
                        title: 'Des rappels à ta façon',
                        text:
                            'Écris tes propres messages, choisis les heures, et active le mode insistant si tu veux être relancé jusqu\'à ce que ce soit fait. Autorise les notifications pour en profiter.',
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _index ? 26 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _index ? accent : context.cs.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(_index < 2 ? 'Continuer' : 'Activer les rappels et commencer'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.hero, required this.title, required this.text, this.child});
  final String hero, title, text;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 48, 28, 16),
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: accentGradient(context.cs.primary),
                boxShadow: [BoxShadow(color: context.cs.primary.withValues(alpha: 0.45), blurRadius: 50)],
              ),
              child: Text(hero, style: const TextStyle(fontSize: 58)),
            ).animate().scale(begin: const Offset(0.6, 0.6), duration: 700.ms, curve: Curves.elasticOut),
            const SizedBox(height: 32),
            Text(title, style: context.tt.headlineMedium, textAlign: TextAlign.center)
                .animate()
                .fadeIn(delay: 150.ms)
                .slideY(begin: 0.2),
            const SizedBox(height: 12),
            Text(text, style: context.tt.bodyLarge?.copyWith(color: context.subtle, height: 1.5), textAlign: TextAlign.center)
                .animate()
                .fadeIn(delay: 250.ms),
            if (child != null) ...[const SizedBox(height: 28), child!.animate().fadeIn(delay: 350.ms)],
          ],
        ),
      );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.icon, this.title, this.text);
  final String icon, title, text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.tt.titleSmall),
              Text(text, style: context.tt.bodySmall?.copyWith(color: context.subtle)),
            ]),
          ),
        ]),
      );
}
