import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Rounded surface card with a hairline border.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.color, this.gradient, this.borderColor});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(24);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: gradient == null ? (color ?? context.cs.surface) : null,
          gradient: gradient,
          borderRadius: r,
          border: Border.all(color: borderColor ?? context.cs.outline.withValues(alpha: gradient == null ? 1 : 0)),
        ),
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 22, 4, 10)});
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: Text(title.toUpperCase(),
                  style: context.tt.labelMedium?.copyWith(color: context.subtle, letterSpacing: 1.4)),
            ),
            ?trailing,
          ],
        ),
      );
}

/// Animated circular progress with rounded caps and a soft glow.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.value,
    this.size = 120,
    this.stroke = 12,
    required this.color,
    this.secondary,
    this.child,
    this.track,
  });

  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color? secondary;
  final Color? track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            v,
            color,
            secondary ?? Color.lerp(color, const Color(0xFFFF5C8A), 0.6)!,
            track ?? context.cs.onSurface.withValues(alpha: 0.08),
            stroke,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.c1, this.c2, this.track, this.stroke);
  final double v;
  final Color c1, c2, track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    canvas.drawArc(r, 0, 2 * pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);
    if (v <= 0) return;
    final sweep = 2 * pi * v;
    final shader = SweepGradient(
      startAngle: 0,
      endAngle: max(sweep, 0.01),
      colors: [c1, c2],
      transform: const GradientRotation(-pi / 2),
    ).createShader(rect);
    canvas.drawArc(
      r,
      -pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = c1.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawArc(
      r,
      -pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.c1 != c1 || o.track != track;
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.icon, this.color, this.filled = false});
  final String label;
  final String? icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? c : c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Text(icon!, style: const TextStyle(fontSize: 12)), const SizedBox(width: 4)],
          Text(label,
              style: context.tt.labelSmall?.copyWith(color: filled ? Colors.white : c, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class EmojiBadge extends StatelessWidget {
  const EmojiBadge(this.emoji, {super.key, required this.color, this.size = 46, this.done = false});
  final String emoji;
  final Color color;
  final double size;
  final bool done;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: done ? 0.28 : 0.16),
          borderRadius: BorderRadius.circular(size * 0.34),
        ),
        child: Text(emoji, style: TextStyle(fontSize: size * 0.48)),
      );
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.icon, this.color});
  final String value;
  final String label;
  final String? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) Text(icon!, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: context.tt.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 2),
            Text(label, style: context.tt.bodySmall?.copyWith(color: context.subtle), maxLines: 2),
          ],
        ),
      );
}

/// Linear progress bar with gradient fill.
class GradientBar extends StatelessWidget {
  const GradientBar({super.key, required this.value, required this.color, this.height = 8});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Container(
          height: height,
          color: context.cs.onSurface.withValues(alpha: 0.08),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.clamp(0, 1)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: Container(decoration: BoxDecoration(gradient: accentGradient(color))),
              ),
            ),
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.emoji, required this.title, required this.message, this.action});
  final String emoji;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(title, style: context.tt.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: context.tt.bodyMedium?.copyWith(color: context.subtle), textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      );
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Max content width for large (desktop) windows.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.max = 760});
  final Widget child;
  final double max;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: max), child: child),
      );
}
