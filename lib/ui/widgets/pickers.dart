import 'package:flutter/material.dart';

import '../../core/theme.dart';

const kEmojiGroups = <String, List<String>>{
  'Santé': ['💧', '🥗', '🍎', '🥦', '💊', '😴', '🛌', '🦷', '🚭', '🍷', '☕', '🧴', '🌞', '🩺', '⚖️', '🫁'],
  'Sport': ['🏃', '🏋️', '🚴', '🧘', '🤸', '🏊', '⚽', '🎾', '🥊', '🧗', '🚶', '💪', '🤾', '⛹️', '🏓', '🛹'],
  'Esprit': ['📚', '✍️', '🧠', '🙏', '📝', '🎧', '🗣️', '🌱', '🕯️', '📓', '🔇', '🧩', '♟️', '🎯', '🪷', '🌙'],
  'Travail': ['💻', '📈', '📧', '🗂️', '⏱️', '📅', '🧑‍💻', '💼', '📊', '🔬', '🎓', '🧮', '📞', '🚀', '🛠️', '✅'],
  'Maison': ['🧹', '🧺', '🍳', '🪴', '🛒', '🐕', '🐈', '👕', '🧽', '🗑️', '🛏️', '🚿', '💰', '🏡', '🔑', '📦'],
  'Créatif': ['🎨', '🎸', '🎹', '📷', '🎬', '🧶', '✂️', '🎤', '🥁', '🎻', '🖌️', '📐', '🪡', '🎮', '🧵', '🌈'],
  'Social': ['❤️', '👨‍👩‍👧', '🤝', '💌', '📱', '🎁', '😊', '🫶', '👋', '🍻', '🥂', '💬', '🌍', '🙌', '⭐', '✨'],
};

Future<String?> pickEmoji(BuildContext context, String current) {
  final ctrl = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        children: [
          Text('Choisis une icône', style: ctx.tt.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: 'Ou tape/colle n\'importe quel emoji…',
              suffixIcon: IconButton(
                icon: const Icon(Icons.check_rounded),
                onPressed: () {
                  final v = ctrl.text.trim();
                  if (v.isNotEmpty) Navigator.pop(ctx, v.characters.first);
                },
              ),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim().characters.first);
            },
          ),
          for (final g in kEmojiGroups.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 8),
              child: Text(g.key, style: ctx.tt.labelLarge?.copyWith(color: ctx.subtle)),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in g.value)
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(ctx, e),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: e == current ? ctx.cs.primary.withValues(alpha: 0.2) : ctx.surface2,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class ColorRow extends StatelessWidget {
  const ColorRow({super.key, required this.value, required this.onChanged, this.colors = AppColors.habitColors});
  final int value;
  final ValueChanged<int> onChanged;
  final List<int> colors;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in colors)
            GestureDetector(
              onTap: () => onChanged(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c == value ? context.cs.onSurface : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: c == value ? [BoxShadow(color: Color(c).withValues(alpha: 0.6), blurRadius: 12)] : null,
                ),
                child: c == value ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
              ),
            ),
        ],
      );
}

class WeekdayPicker extends StatelessWidget {
  const WeekdayPicker({super.key, required this.value, required this.onChanged, required this.color});
  final Set<int> value;
  final ValueChanged<Set<int>> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var d = 1; d <= 7; d++)
          GestureDetector(
            onTap: () {
              final next = {...value};
              next.contains(d) ? next.remove(d) : next.add(d);
              if (next.isNotEmpty) onChanged(next);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value.contains(d) ? color : context.surface2,
              ),
              child: Text(
                labels[d - 1],
                style: context.tt.titleSmall?.copyWith(color: value.contains(d) ? Colors.white : context.subtle),
              ),
            ),
          ),
      ],
    );
  }
}
