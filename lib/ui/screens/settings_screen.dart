import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/habit_store.dart';
import '../../logic/messages.dart';
import '../../models/app_settings.dart';
import '../../services/desktop_service.dart';
import '../../services/notification_service.dart';
import '../../services/social_service.dart';
import '../../services/widget_service.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<HabitStore>();
    final s = store.settings;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      appBar: canPop ? AppBar(title: const Text('Réglages')) : null,
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              if (!canPop) Text('Réglages', style: context.tt.headlineMedium),
              const SectionHeader('Profil'),
              AppCard(
                padding: const EdgeInsets.all(14),
                child: TextFormField(
                  initialValue: s.userName,
                  decoration: const InputDecoration(labelText: 'Ton prénom (utilisé dans les messages : {prenom})'),
                  onFieldSubmitted: (v) => store.updateSettings((s) => s.userName = v.trim(), reschedule: true),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  onChanged: (v) => s.userName = v.trim(),
                ),
              ),

              const SectionHeader('Apparence'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Sombre')),
                          ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Clair')),
                          ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Auto')),
                        ],
                        selected: {s.themeMode},
                        onSelectionChanged: (v) => store.updateSettings((s) => s.themeMode = v.first),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Couleur d\'accent', style: context.tt.labelLarge?.copyWith(color: context.subtle)),
                    const SizedBox(height: 10),
                    ColorRow(
                      value: s.accent,
                      colors: AppColors.accents,
                      onChanged: (v) => store.updateSettings((s) => s.accent = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  SwitchListTile(
                    value: s.celebrations,
                    onChanged: (v) => store.updateSettings((s) => s.celebrations = v),
                    title: const Text('Célébrations (confettis)'),
                  ),
                  SwitchListTile(
                    value: s.haptics,
                    onChanged: (v) => store.updateSettings((s) => s.haptics = v),
                    title: const Text('Vibrations'),
                  ),
                ]),
              ),

              const SectionHeader('Notifications'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_active_rounded),
                    title: const Text('Autoriser les notifications'),
                    subtitle: const Text('Et les alarmes exactes, pour des rappels à l\'heure pile'),
                    onTap: () async {
                      await NotificationService.requestPermissions();
                      await NotificationService.rescheduleAll(store.data);
                      final n = await NotificationService.pendingCount();
                      if (context.mounted) toast(context, n >= 0 ? '$n rappels programmés ✔︎' : 'Rappels reprogrammés ✔︎');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.snooze_rounded),
                    title: const Text('Durée de « Plus tard »'),
                    trailing: DropdownButton<int>(
                      value: s.snoozeMinutes,
                      underline: const SizedBox(),
                      items: [5, 10, 15, 20, 30, 45, 60, 90, 120]
                          .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                          .toList(),
                      onChanged: (v) => store.updateSettings((s) => s.snoozeMinutes = v ?? 10),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bedtime_rounded),
                    title: const Text('Pas de relances insistantes'),
                    subtitle: Text('Entre ${s.nagStopHour}h et ${s.nagStartHour}h'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButton<int>(
                        value: s.nagStopHour,
                        underline: const SizedBox(),
                        items: [for (var h = 18; h <= 24; h++) DropdownMenuItem(value: h, child: Text('${h}h'))],
                        onChanged: (v) => store.updateSettings((s) => s.nagStopHour = v ?? 23, reschedule: true),
                      ),
                      const Text(' → '),
                      DropdownButton<int>(
                        value: s.nagStartHour,
                        underline: const SizedBox(),
                        items: [for (var h = 4; h <= 11; h++) DropdownMenuItem(value: h, child: Text('${h}h'))],
                        onChanged: (v) => store.updateSettings((s) => s.nagStartHour = v ?? 7, reschedule: true),
                      ),
                    ]),
                  ),
                  ListTile(
                    leading: const Icon(Icons.campaign_rounded),
                    title: const Text('Messages de relance par défaut'),
                    subtitle: Text('${s.defaultNagMessages.length} messages · utilisés quand un rappel n\'a pas les siens'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _NagMessagesScreen())),
                  ),
                ]),
              ),

              if (WidgetService.supported) ...[
                const SectionHeader('Widgets écran d\'accueil'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    ListTile(
                      leading: const Text('📋', style: TextStyle(fontSize: 22)),
                      title: const Text('Ajouter le widget « Aujourd\'hui »'),
                      subtitle: const Text('Liste des habitudes, à cocher directement'),
                      onTap: () => WidgetService.requestPin(),
                    ),
                    ListTile(
                      leading: const Text('🎯', style: TextStyle(fontSize: 22)),
                      title: const Text('Ajouter le widget « Progression »'),
                      subtitle: const Text('Anneau du jour, série et niveau'),
                      onTap: () => WidgetService.requestPin(progress: true),
                    ),
                  ]),
                ),
              ],

              if (DesktopService.supported) ...[
                const SectionHeader('Windows'),
                AppCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    ListTile(
                      leading: const Icon(Icons.picture_in_picture_alt_rounded),
                      title: const Text('Ouvrir le mini-widget'),
                      subtitle: const Text('Petite fenêtre avec les habitudes du jour'),
                      onTap: () => context.read<DesktopService>().enterMini(alwaysOnTop: s.miniAlwaysOnTop),
                    ),
                    SwitchListTile(
                      value: s.miniAlwaysOnTop,
                      onChanged: (v) => store.updateSettings((s) => s.miniAlwaysOnTop = v),
                      title: const Text('Mini-widget toujours au premier plan'),
                    ),
                  ]),
                ),
              ],

              const SectionHeader('Serveur multijoueur'),
              const _ServerCard(),

              const SectionHeader('Données'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.upload_rounded),
                    title: const Text('Exporter une sauvegarde'),
                    subtitle: const Text('Copie dans le presse-papiers + fichier'),
                    onTap: () async {
                      final json = await store.exportJson();
                      await Clipboard.setData(ClipboardData(text: json));
                      final dir = Platform.isAndroid
                          ? (await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory())
                          : await getApplicationDocumentsDirectory();
                      final f = File('${dir.path}${Platform.pathSeparator}rituel_backup.json');
                      await f.writeAsString(json);
                      if (context.mounted) toast(context, 'Sauvegarde copiée et enregistrée dans ${f.path}');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.download_rounded),
                    title: const Text('Importer une sauvegarde'),
                    subtitle: const Text('Colle le contenu d\'un export'),
                    onTap: () => _import(context),
                  ),
                ]),
              ),
              const SizedBox(height: 28),
              Center(
                child: Text('Rituel · fait avec 💜 pour tenir parole envers soi-même',
                    style: context.tt.labelSmall?.copyWith(color: context.faint)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _import(BuildContext context) async {
    final ctrl = TextEditingController();
    final clip = await Clipboard.getData('text/plain');
    if (clip?.text?.trimLeft().startsWith('{') ?? false) ctrl.text = clip!.text!;
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importer'),
        content: SizedBox(
          width: 480,
          child: TextField(controller: ctrl, maxLines: 8, decoration: const InputDecoration(hintText: '{ … }')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remplacer mes données')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<HabitStore>().importJson(ctrl.text);
      if (context.mounted) toast(context, 'Données importées ✔︎');
    } catch (e) {
      if (context.mounted) toast(context, 'Fichier invalide : $e');
    }
  }
}

class _ServerCard extends StatefulWidget {
  const _ServerCard();

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  late final store = context.read<HabitStore>();
  late final _url = TextEditingController(text: store.settings.supabaseUrl);
  late final _key = TextEditingController(text: store.settings.supabaseAnonKey);

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialService>();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.circle, size: 10, color: social.configured ? AppColors.success : AppColors.danger),
            const SizedBox(width: 8),
            Text(social.configured ? (social.signedIn ? 'Connecté' : 'Serveur configuré') : 'Non configuré',
                style: context.tt.labelLarge),
          ]),
          const SizedBox(height: 6),
          Text(
            'Projet Supabase gratuit (voir README). Tous tes amis doivent utiliser le même serveur.',
            style: context.tt.bodySmall?.copyWith(color: context.subtle),
          ),
          const SizedBox(height: 12),
          TextField(controller: _url, decoration: const InputDecoration(labelText: 'URL du projet (https://xxx.supabase.co)')),
          const SizedBox(height: 10),
          TextField(controller: _key, decoration: const InputDecoration(labelText: 'Clé publique (publishable / anon)')),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () async {
              await store.updateSettings((s) {
                s.supabaseUrl = _url.text.trim();
                s.supabaseAnonKey = _key.text.trim();
              });
              if (!social.configured) await social.init(store.settings);
              if (context.mounted) {
                toast(context, social.configured ? 'Serveur connecté ✔︎' : 'Enregistré. Redémarre l\'app pour appliquer.');
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class _NagMessagesScreen extends StatefulWidget {
  const _NagMessagesScreen();

  @override
  State<_NagMessagesScreen> createState() => _NagMessagesScreenState();
}

class _NagMessagesScreenState extends State<_NagMessagesScreen> {
  late final store = context.read<HabitStore>();
  late final List<TextEditingController> _ctrls = [
    for (final m in store.settings.defaultNagMessages) TextEditingController(text: m),
  ];

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    await store.updateSettings(
      (s) => s.defaultNagMessages = _ctrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
      reschedule: true,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Relances par défaut'),
          actions: [
            TextButton(
              onPressed: () => setState(() {
                for (final c in _ctrls) {
                  c.dispose();
                }
                _ctrls
                  ..clear()
                  ..addAll(kDefaultNagMessagesCtrls());
              }),
              child: const Text('Réinitialiser'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: _save, child: const Text('OK')),
            ),
          ],
        ),
        body: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Text(
                'Envoyés à tour de rôle en mode insistant. Variables : ${kPlaceholders.keys.join(' ')}',
                style: context.tt.bodySmall?.copyWith(color: context.subtle),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _ctrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrls[i],
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(labelText: 'Relance ${i + 1}'),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _ctrls.removeAt(i).dispose()),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ]),
                ),
              OutlinedButton.icon(
                onPressed: () => setState(() => _ctrls.add(TextEditingController())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ajouter'),
              ),
            ],
          ),
        ),
      );
}

List<TextEditingController> kDefaultNagMessagesCtrls() => [
      for (final m in kDefaultNagMessages) TextEditingController(text: m),
    ];
