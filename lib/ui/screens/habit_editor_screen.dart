import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../data/habit_store.dart';
import '../../models/habit.dart';
import '../../services/notification_service.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';
import 'reminder_editor_screen.dart';

class HabitTemplate {
  const HabitTemplate(this.emoji, this.name, this.color,
      {this.target = 1, this.unit = '', this.identity = '', this.mini = '', this.cue = '', this.hour = 9});
  final String emoji, name, unit, identity, mini, cue;
  final int color, target, hour;
}

const kTemplates = [
  HabitTemplate('💧', 'Boire de l\'eau', 0xFF38BDF8,
      target: 8, unit: 'verres', identity: 'prend soin de son corps', mini: 'Boire un grand verre', cue: 'Au réveil', hour: 10),
  HabitTemplate('📚', 'Lire', 0xFFFFC94D,
      identity: 'lit tous les jours', mini: 'Lire une page', cue: 'Après m\'être couché', hour: 22),
  HabitTemplate('🧘', 'Méditer', 0xFF9D6BFF,
      identity: 'reste calme et présent', mini: '3 respirations profondes', cue: 'Après mon café', hour: 8),
  HabitTemplate('🏃', 'Faire du sport', 0xFFFF5C8A,
      identity: 'est en forme', mini: 'Mettre mes baskets et faire 10 squats', cue: 'En rentrant du travail', hour: 18),
  HabitTemplate('✍️', 'Écrire mon journal', 0xFF22C3A6,
      identity: 'réfléchit à sa vie', mini: 'Écrire une phrase', cue: 'Avant de dormir', hour: 21),
  HabitTemplate('📵', 'Pas d\'écran au lit', 0xFF6366F1,
      identity: 'dort bien', mini: 'Poser le téléphone hors de la chambre', cue: 'À 22h30', hour: 22),
  HabitTemplate('🥗', 'Manger sain', 0xFFA3E635,
      identity: 'nourrit bien son corps', mini: 'Ajouter un légume au repas', cue: 'Au déjeuner', hour: 12),
  HabitTemplate('🇬🇧', 'Pratiquer une langue', 0xFF3D8BFF,
      identity: 'parle plusieurs langues', mini: 'Une leçon de 2 minutes', cue: 'Dans les transports', hour: 8),
];

class HabitEditorScreen extends StatefulWidget {
  const HabitEditorScreen({super.key, this.habit});
  final Habit? habit;

  @override
  State<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends State<HabitEditorScreen> {
  late final Habit h = widget.habit?.copy() ?? Habit(name: '', reminders: [Reminder(hour: 9)]);
  late final _name = TextEditingController(text: h.name);
  late final _unit = TextEditingController(text: h.unit);
  late final _why = TextEditingController(text: h.why);
  late final _identity = TextEditingController(text: h.identity);
  late final _cue = TextEditingController(text: h.cue);
  late final _location = TextEditingController(text: h.location);
  late final _mini = TextEditingController(text: h.miniVersion);
  late final _notes = TextEditingController(text: h.notes);
  bool get isNew => widget.habit == null;

  @override
  void dispose() {
    for (final c in [_name, _unit, _why, _identity, _cue, _location, _mini, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyTemplate(HabitTemplate t) {
    setState(() {
      h.emoji = t.emoji;
      h.color = t.color;
      h.target = t.target;
      _name.text = t.name;
      _unit.text = t.unit;
      _identity.text = t.identity;
      _mini.text = t.mini;
      _cue.text = t.cue;
      if (h.reminders.length == 1) {
        h.reminders.first.hour = t.hour;
        h.reminders.first.minute = 0;
      }
    });
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      toast(context, 'Donne un nom à ton habitude ✍️');
      return;
    }
    h
      ..name = _name.text.trim()
      ..unit = _unit.text.trim()
      ..why = _why.text.trim()
      ..identity = _identity.text.trim()
      ..cue = _cue.text.trim()
      ..location = _location.text.trim()
      ..miniVersion = _mini.text.trim()
      ..notes = _notes.text.trim();
    final store = context.read<HabitStore>();
    if (isNew) {
      if (h.reminders.isNotEmpty) await NotificationService.requestPermissions();
      await store.addHabit(h);
    } else {
      await store.updateHabit(h);
    }
    if (mounted) Navigator.pop(context, h);
  }

  @override
  Widget build(BuildContext context) {
    final c = Color(h.color);
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Nouvelle habitude' : 'Modifier'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40), backgroundColor: c),
              onPressed: _save,
              child: const Text('Enregistrer'),
            ),
          ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            // ---------------------------------------------------- identity
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final e = await pickEmoji(context, h.emoji);
                    if (e != null) setState(() => h.emoji = e);
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      EmojiBadge(h.emoji, color: c, size: 72),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: CircleAvatar(
                          radius: 13,
                          backgroundColor: c,
                          child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: isNew,
                    textCapitalization: TextCapitalization.sentences,
                    style: context.tt.titleLarge,
                    decoration: const InputDecoration(hintText: 'Nom de l\'habitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ColorRow(value: h.color, onChanged: (v) => setState(() => h.color = v)),

            if (isNew) ...[
              const SectionHeader('Partir d\'un modèle'),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kTemplates.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ActionChip(
                    avatar: Text(kTemplates[i].emoji),
                    label: Text(kTemplates[i].name),
                    onPressed: () => _applyTemplate(kTemplates[i]),
                  ),
                ),
              ),
            ],

            // --------------------------------------------------- frequency
            const SectionHeader('Fréquence'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<FrequencyType>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: FrequencyType.daily, label: Text('Chaque jour')),
                        ButtonSegment(value: FrequencyType.weekdays, label: Text('Jours fixes')),
                        ButtonSegment(value: FrequencyType.perWeek, label: Text('X / sem.')),
                      ],
                      selected: {h.frequency},
                      onSelectionChanged: (s) => setState(() => h.frequency = s.first),
                    ),
                  ),
                  if (h.frequency == FrequencyType.weekdays) ...[
                    const SizedBox(height: 16),
                    WeekdayPicker(value: h.weekdays, color: c, onChanged: (v) => setState(() => h.weekdays = v)),
                  ],
                  if (h.frequency == FrequencyType.perWeek) ...[
                    const SizedBox(height: 12),
                    _Stepper(
                      label: 'Jours par semaine',
                      value: h.perWeek,
                      min: 1,
                      max: 7,
                      color: c,
                      onChanged: (v) => setState(() => h.perWeek = v),
                    ),
                  ],
                ],
              ),
            ),

            // ------------------------------------------------------ target
            const SectionHeader('Objectif quotidien'),
            AppCard(
              child: Column(
                children: [
                  _Stepper(
                    label: 'Répétitions par jour',
                    value: h.target,
                    min: 1,
                    max: 100,
                    color: c,
                    onChanged: (v) => setState(() => h.target = v),
                  ),
                  if (h.target > 1) ...[
                    const SizedBox(height: 12),
                    TextField(controller: _unit, decoration: const InputDecoration(hintText: 'Unité (verres, pages, minutes…)')),
                  ],
                ],
              ),
            ),

            // -------------------------------------------------- psychology
            const SectionHeader('Ancrer l\'habitude'),
            _PsyField(
              icon: '🪞',
              title: 'Identité',
              help: 'Les habitudes durables viennent de qui tu veux être, pas de ce que tu veux obtenir.',
              prefix: 'Je suis quelqu\'un qui…',
              hint: 'prend soin de sa santé',
              controller: _identity,
            ),
            _PsyField(
              icon: '🔗',
              title: 'Déclencheur (intention de mise en œuvre)',
              help: 'Lier la nouvelle habitude à un moment précis double tes chances de la faire.',
              prefix: 'Quand / Après…',
              hint: 'Après mon café du matin',
              controller: _cue,
            ),
            _PsyField(
              icon: '📍',
              title: 'Lieu',
              help: 'Un environnement dédié devient un signal automatique.',
              prefix: 'Où ?',
              hint: 'Dans le salon, sur le tapis',
              controller: _location,
            ),
            _PsyField(
              icon: '🤏',
              title: 'Version 2 minutes',
              help: 'Les jours difficiles, cette version minimale suffit à garder la série. Commencer est ce qui compte.',
              prefix: 'Au minimum, je…',
              hint: 'Lire une seule page',
              controller: _mini,
            ),
            _PsyField(
              icon: '❤️',
              title: 'Pourquoi c\'est important',
              help: 'Ta motivation profonde apparaîtra dans les rappels et les moments de doute.',
              prefix: 'Parce que…',
              hint: 'Je veux avoir de l\'énergie pour mes enfants',
              controller: _why,
              lines: 2,
            ),

            // --------------------------------------------------- reminders
            SectionHeader(
              'Rappels',
              trailing: TextButton.icon(
                onPressed: () async {
                  final r = await Navigator.push<Reminder>(
                    context,
                    MaterialPageRoute(builder: (_) => ReminderEditorScreen(reminder: Reminder(hour: 20), habit: _preview())),
                  );
                  if (r != null) setState(() => h.reminders.add(r));
                },
                icon: const Icon(Icons.add_alarm_rounded, size: 18),
                label: const Text('Ajouter'),
              ),
            ),
            if (h.reminders.isEmpty)
              AppCard(
                child: Text('Aucun rappel. Ajoute-en un pour être notifié avec ton propre message.',
                    style: context.tt.bodySmall?.copyWith(color: context.subtle)),
              ),
            for (final r in h.reminders)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  onTap: () async {
                    final edited = await Navigator.push<Reminder>(
                      context,
                      MaterialPageRoute(builder: (_) => ReminderEditorScreen(reminder: r.copy(), habit: _preview())),
                    );
                    if (edited != null) {
                      setState(() => h.reminders[h.reminders.indexWhere((e) => e.id == r.id)] = edited);
                    }
                  },
                  child: Row(
                    children: [
                      Text(hm(r.hour, r.minute),
                          style: context.tt.headlineSmall?.copyWith(
                              color: r.enabled ? null : context.faint, fontFeatures: const [FontFeature.tabularFigures()])),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.body.isEmpty ? r.title : r.body,
                                maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.bodySmall),
                            if (r.nag) ...[
                              const SizedBox(height: 4),
                              Pill(
                                icon: '🔁',
                                label: 'Insistant · toutes les ${r.nagIntervalMinutes} min',
                                color: AppColors.danger,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Switch(value: r.enabled, onChanged: (v) => setState(() => r.enabled = v)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => setState(() => h.reminders.remove(r)),
                      ),
                    ],
                  ),
                ),
              ),

            // ------------------------------------------------------- other
            const SectionHeader('Autres'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    value: h.shareWithFriends,
                    onChanged: (v) => setState(() => h.shareWithFriends = v),
                    title: const Text('Visible par mes amis'),
                    subtitle: const Text('Tes amis voient ta série et ta régularité'),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: TextField(
                      controller: _notes,
                      maxLines: 3,
                      minLines: 1,
                      decoration: const InputDecoration(hintText: 'Notes personnelles'),
                    ),
                  ),
                ],
              ),
            ),
            if (!isNew) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  final store = context.read<HabitStore>();
                  await store.setArchived(widget.habit!, !widget.habit!.archived);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: Icon(widget.habit!.archived ? Icons.unarchive_rounded : Icons.archive_outlined),
                label: Text(widget.habit!.archived ? 'Réactiver' : 'Mettre en pause (archiver)'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_forever_rounded),
                label: const Text('Supprimer définitivement'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Current form state, used to preview notification texts.
  Habit _preview() => h.copy()
    ..name = _name.text.trim().isEmpty ? 'Mon habitude' : _name.text.trim()
    ..why = _why.text.trim()
    ..identity = _identity.text.trim()
    ..cue = _cue.text.trim()
    ..location = _location.text.trim()
    ..miniVersion = _mini.text.trim()
    ..unit = _unit.text.trim();

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: const Text('L\'historique de cette habitude sera perdu. Tu peux plutôt l\'archiver pour la mettre en pause.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<HabitStore>().deleteHabit(widget.habit!);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged, required this.color});
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label, style: context.tt.bodyLarge)),
          IconButton.filledTonal(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 48,
            child: Text('$value', textAlign: TextAlign.center, style: context.tt.titleLarge?.copyWith(color: color)),
          ),
          IconButton.filledTonal(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      );
}

class _PsyField extends StatelessWidget {
  const _PsyField({
    required this.icon,
    required this.title,
    required this.help,
    required this.prefix,
    required this.hint,
    required this.controller,
    this.lines = 1,
  });
  final String icon, title, help, prefix, hint;
  final TextEditingController controller;
  final int lines;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: context.tt.titleSmall)),
              ]),
              const SizedBox(height: 4),
              Text(help, style: context.tt.bodySmall?.copyWith(color: context.subtle)),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                maxLines: lines,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(prefixText: '$prefix ', hintText: hint),
              ),
            ],
          ),
        ),
      );
}
