import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../data/habit_store.dart';
import '../../logic/messages.dart';
import '../../models/habit.dart';
import '../../services/notification_service.dart';
import '../widgets/common.dart';

/// Every word of a reminder is editable; placeholders are filled at send time.
class ReminderEditorScreen extends StatefulWidget {
  const ReminderEditorScreen({super.key, required this.reminder, required this.habit});
  final Reminder reminder;
  final Habit habit;

  @override
  State<ReminderEditorScreen> createState() => _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends State<ReminderEditorScreen> {
  late final Reminder r = widget.reminder;
  late final _title = TextEditingController(text: r.title);
  late final _body = TextEditingController(text: r.body);
  late final List<TextEditingController> _nags = [for (final m in r.nagMessages) TextEditingController(text: m)];
  late TextEditingController _focused = _body;

  @override
  void initState() {
    super.initState();
    for (final c in [_title, _body, ..._nags]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _body, ..._nags]) {
      c.dispose();
    }
    super.dispose();
  }

  void _insert(String token) {
    final c = _focused;
    final sel = c.selection;
    final text = c.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    c.value = TextEditingValue(
      text: text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
  }

  Reminder _result() => r
    ..title = _title.text
    ..body = _body.text
    ..nagMessages = _nags.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final settings = context.read<HabitStore>().settings;
    final c = Color(widget.habit.color);
    final title = renderMessage(_title.text, widget.habit, userName: settings.userName);
    final body = renderMessage(_body.text, widget.habit, userName: settings.userName);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rappel'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40), backgroundColor: c),
              onPressed: () => Navigator.pop(context, _result()),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            // Time
            AppCard(
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: r.hour, minute: r.minute));
                if (t != null) setState(() => r..hour = t.hour..minute = t.minute);
              },
              child: Row(
                children: [
                  Text(hm(r.hour, r.minute), style: context.tt.displayMedium?.copyWith(color: c)),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Switch(value: r.enabled, onChanged: (v) => setState(() => r.enabled = v)),
                      Text('Toucher pour changer l\'heure', style: context.tt.labelSmall?.copyWith(color: context.subtle)),
                    ],
                  ),
                ],
              ),
            ),

            // Live preview
            const SectionHeader('Aperçu'),
            _NotificationPreview(habit: widget.habit, title: title, body: body),

            const SectionHeader('Message'),
            TextField(
              controller: _title,
              onTap: () => _focused = _title,
              decoration: const InputDecoration(labelText: 'Titre de la notification'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              onTap: () => _focused = _body,
              maxLines: 4,
              minLines: 2,
              decoration: const InputDecoration(labelText: 'Texte de la notification'),
            ),
            const SizedBox(height: 10),
            Text('Variables (touche pour insérer dans le champ sélectionné) :',
                style: context.tt.bodySmall?.copyWith(color: context.subtle)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in kPlaceholders.entries)
                  Tooltip(
                    message: e.value,
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(e.key, style: const TextStyle(fontSize: 12)),
                      onPressed: () => _insert(e.key),
                    ),
                  ),
              ],
            ),

            // Nag mode
            const SectionHeader('Mode insistant'),
            AppCard(
              borderColor: r.nag ? AppColors.danger.withValues(alpha: 0.5) : null,
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: r.nag,
                    onChanged: (v) => setState(() => r.nag = v),
                    title: const Text('Me relancer jusqu\'à ce que ce soit fait 😈'),
                    subtitle: Text(
                      'Des notifications répétées après l\'heure du rappel. Elles s\'arrêtent dès que tu valides '
                      '(depuis l\'app, le widget ou le bouton « C\'est fait » de la notification). '
                      'Jamais entre ${settings.nagStopHour}h et ${settings.nagStartHour}h.',
                    ),
                  ),
                  if (r.nag) ...[
                    _SliderRow(
                      label: 'Toutes les',
                      valueLabel: '${r.nagIntervalMinutes} min',
                      value: r.nagIntervalMinutes.toDouble(),
                      min: 5,
                      max: 120,
                      divisions: 23,
                      onChanged: (v) => setState(() => r.nagIntervalMinutes = v.round()),
                    ),
                    _SliderRow(
                      label: 'Maximum',
                      valueLabel: '${r.nagMaxCount} relances',
                      value: r.nagMaxCount.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      onChanged: (v) => setState(() => r.nagMaxCount = v.round()),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        'Messages des relances (utilisés à tour de rôle). '
                        '${_nags.isEmpty ? 'Vide = messages par défaut des réglages.' : ''}',
                        style: context.tt.bodySmall?.copyWith(color: context.subtle),
                      ),
                    ),
                    for (var i = 0; i < _nags.length; i++)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 4, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nags[i],
                                onTap: () => _focused = _nags[i],
                                maxLines: 2,
                                minLines: 1,
                                decoration: InputDecoration(labelText: 'Relance ${i + 1}'),
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _nags.removeAt(i).dispose()),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => setState(() {
                              final ctrl = TextEditingController()..addListener(() => setState(() {}));
                              _nags.add(ctrl);
                              _focused = ctrl;
                            }),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Ajouter un message'),
                          ),
                          if (_nags.isEmpty)
                            TextButton(
                              onPressed: () => setState(() {
                                for (final m in settings.defaultNagMessages) {
                                  _nags.add(TextEditingController(text: m)..addListener(() => setState(() {})));
                                }
                              }),
                              child: const Text('Partir des messages par défaut'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                await NotificationService.requestPermissions();
                await NotificationService.preview(widget.habit, _result(), settings);
                if (r.nag) {
                  await Future<void>.delayed(const Duration(seconds: 2));
                  await NotificationService.preview(widget.habit, _result(), settings, nag: true);
                }
                if (context.mounted) toast(context, 'Notification de test envoyée 📬');
              },
              icon: const Icon(Icons.notifications_active_rounded),
              label: const Text('Envoyer une notification de test'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label, valueLabel;
  final double value, min, max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(width: 80, child: Text(label, style: context.tt.bodyMedium)),
            Expanded(
              child: Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
            ),
            SizedBox(width: 92, child: Text(valueLabel, textAlign: TextAlign.end, style: context.tt.labelLarge)),
          ],
        ),
      );
}

class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({required this.habit, required this.title, required this.body});
  final Habit habit;
  final String title, body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.surface2,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(gradient: accentGradient(Color(habit.color)), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text('Rituel · maintenant', style: context.tt.labelSmall?.copyWith(color: context.subtle)),
            ]),
            const SizedBox(height: 8),
            Text(title, style: context.tt.titleSmall),
            const SizedBox(height: 2),
            Text(body, style: context.tt.bodyMedium?.copyWith(color: context.subtle)),
            const SizedBox(height: 10),
            Wrap(spacing: 16, children: [
              Text(habit.target > 1 ? '+1' : '✓ C\'est fait', style: context.tt.labelLarge?.copyWith(color: Color(habit.color))),
              if (habit.miniVersion.isNotEmpty)
                Text('🤏 Version mini', style: context.tt.labelLarge?.copyWith(color: Color(habit.color))),
              Text('⏰ Plus tard', style: context.tt.labelLarge?.copyWith(color: Color(habit.color))),
            ]),
          ],
        ),
      );
}
