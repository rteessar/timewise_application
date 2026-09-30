import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../planner/domain/auto_planner.dart';
import '../../planner/domain/habit_profile.dart';
import 'week_layout.dart';

/// Paints the week as a map of your time:
/// green = free time (brighter where you work best), hatched orange = free
/// time too short to use, solid blocks = commitments.
class WeekPainter extends CustomPainter {
  WeekPainter({
    required this.layout,
    required this.profile,
    required this.wasted,
    required this.now,
    required this.scheme,
  });

  final WeekLayout layout;
  final HabitProfile profile;
  final List<Span> wasted;
  final DateTime now;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final hh = layout.hourHeight;
    final grid = Paint()..color = scheme.outlineVariant.withValues(alpha: 0.5);

    // hour lines + labels
    for (var h = kFirstHour; h <= kLastHour; h++) {
      final y = (h - kFirstHour) * hh;
      canvas.drawLine(Offset(kTimeColWidth, y), Offset(size.width, y), grid);
      if (h < kLastHour) {
        _text(
          canvas,
          '${h.toString().padLeft(2, '0')}:00',
          Offset(2, y + 2),
          TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
          kTimeColWidth - 4,
        );
      }
    }

    for (var i = 0; i < layout.days.length; i++) {
      final d = layout.days[i];
      final x0 = layout.columnX(i);
      final working = profile.workDays.contains(d.weekday);

      // availability heat
      for (var h = kFirstHour; h < kLastHour; h++) {
        final inHours =
            working && h >= profile.workStartHour && h < profile.workEndHour;
        final y = (h - kFirstHour) * hh;
        final rect = Rect.fromLTWH(x0, y, layout.columnWidth, hh);
        if (inHours) {
          final t =
              ((profile.weightAt(h) - HabitProfile.minWeight) /
                      (HabitProfile.maxWeight - HabitProfile.minWeight))
                  .clamp(0.0, 1.0);
          canvas.drawRect(
            rect,
            Paint()
              ..color = const Color(
                0xFF22C55E,
              ).withValues(alpha: 0.05 + 0.25 * t),
          );
        } else {
          canvas.drawRect(
            rect,
            Paint()..color = scheme.onSurface.withValues(alpha: 0.05),
          );
        }
      }
      canvas.drawLine(Offset(x0, 0), Offset(x0, size.height), grid);

      // today highlight line
      if (_sameDay(d, now)) {
        final y = layout.yOf(now);
        if (y >= 0 && y <= size.height) {
          final p = Paint()
            ..color = scheme.error
            ..strokeWidth = 1.5;
          canvas.drawLine(Offset(x0, y), Offset(x0 + layout.columnWidth, y), p);
          canvas.drawCircle(Offset(x0, y), 3.5, p);
        }
      }
    }

    // wasted slivers: hatch
    final hatch = Paint()
      ..color = scheme.tertiary.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    for (final g in wasted) {
      for (var i = 0; i < layout.days.length; i++) {
        if (!_sameDay(layout.days[i], g.start)) continue;
        final r = Rect.fromLTRB(
          layout.columnX(i) + 2,
          layout.yOf(g.start),
          layout.columnX(i) + layout.columnWidth - 2,
          layout.yOf(g.end),
        );
        canvas.save();
        canvas.clipRect(r);
        for (var x = r.left - r.height; x < r.right; x += 6) {
          canvas.drawLine(
            Offset(x, r.bottom),
            Offset(x + r.height, r.top),
            hatch,
          );
        }
        canvas.restore();
      }
    }

    // tasks
    for (final b in layout.bars) {
      final color = b.project.color;
      final done = b.task.done;
      final rr = RRect.fromRectAndRadius(b.rect, const Radius.circular(6));
      canvas.drawRRect(
        rr,
        Paint()..color = color.withValues(alpha: done ? 0.35 : 0.95),
      );
      if (b.task.autoPlaced && !done) {
        // dashed-look marker: planned by TimeWise
        canvas.drawRRect(
          rr.deflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withValues(alpha: 0.7),
        );
      }
      if (b.rect.height > 16 && b.rect.width > 20) {
        final light =
            ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
        _text(
          canvas,
          '${done ? '✓ ' : ''}${b.task.title}',
          b.rect.topLeft + const Offset(4, 3),
          TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: done
                ? scheme.onSurface
                : (light ? Colors.white : Colors.black87),
            decoration: done ? TextDecoration.lineThrough : null,
          ),
          b.rect.width - 8,
          maxLines: ((b.rect.height - 6) / 14).floor().clamp(1, 6),
        );
      }
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _text(
    Canvas canvas,
    String s,
    Offset at,
    TextStyle style,
    double maxW, {
    int maxLines = 1,
  }) {
    if (maxW <= 0) return;
    final tp = TextPainter(
      text: TextSpan(text: s, style: style),
      maxLines: maxLines,
      ellipsis: '…',
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxW);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(WeekPainter old) => true;
}
