import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../planner/domain/auto_planner.dart';
import '../../planner/domain/habit_profile.dart';
import 'map_layout.dart';
import 'map_viewport.dart';

/// Paints the map. Content (shading, tasks) scrolls in both axes while the
/// date header and hour gutter stay pinned. Detail adapts to the zoom.
class MapPainter extends CustomPainter {
  MapPainter({
    required this.viewport,
    required this.bars,
    required this.profile,
    required this.wasted,
    required this.now,
    required this.scheme,
  });

  final MapViewport viewport;
  final List<MapBar> bars;
  final HabitProfile profile;
  final List<Span> wasted;
  final DateTime now;
  final ColorScheme scheme;

  static const _gutter = MapViewport.gutterWidth;
  static const _header = MapViewport.headerHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final v = viewport;
    final content = Rect.fromLTWH(
      _gutter,
      _header,
      size.width - _gutter,
      size.height - _header,
    );
    final grid = Paint()..color = scheme.outlineVariant.withValues(alpha: 0.5);

    canvas.save();
    canvas.clipRect(content);
    _paintDays(canvas, size, grid);
    _paintWasted(canvas);
    _paintBars(canvas);
    _paintNow(canvas);
    canvas.restore();

    _paintHeader(canvas, size, grid);
    _paintGutter(canvas, size, grid);
    // corner
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _gutter, _header),
      Paint()..color = scheme.surface,
    );
    canvas.drawLine(
      const Offset(0, _header),
      Offset(size.width, _header),
      Paint()..color = scheme.outlineVariant,
    );
    canvas.drawLine(
      Offset(_gutter, 0),
      Offset(_gutter, size.height),
      Paint()..color = scheme.outlineVariant,
    );
    if (v.zoom < 0) return;
  }

  void _paintDays(Canvas canvas, Size size, Paint grid) {
    final v = viewport;
    final hh = v.hourHeight;
    for (var d = v.firstDay; d <= v.lastDay; d++) {
      final date = dateOfDay(d);
      final x0 = v.xOfDay(d);
      final w = v.columnWidth;
      final working = profile.workDays.contains(date.weekday);
      for (var h = 0; h < 24; h++) {
        final y = v.yOfHour(h.toDouble());
        if (y > size.height || y + hh < _header) continue;
        final rect = Rect.fromLTWH(x0, y, w, hh);
        final inHours =
            working && h >= profile.workStartHour && h < profile.workEndHour;
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
      // hour lines (thinner when zoomed out)
      final step = _hourStep(hh);
      for (var h = 0; h <= 24; h += step) {
        final y = v.yOfHour(h.toDouble());
        canvas.drawLine(Offset(x0, y), Offset(x0 + w, y), grid);
      }
      canvas.drawLine(Offset(x0, _header), Offset(x0, size.height), grid);
      if (date.day == 1) {
        canvas.drawLine(
          Offset(x0, _header),
          Offset(x0, size.height),
          Paint()
            ..color = scheme.outline.withValues(alpha: 0.6)
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _paintWasted(Canvas canvas) {
    final v = viewport;
    final hatch = Paint()
      ..color = scheme.tertiary.withValues(alpha: 0.75)
      ..strokeWidth = 1;
    for (final g in wasted) {
      final d = dayNumber(g.start);
      final r = Rect.fromLTRB(
        v.xOfDay(d) + 2,
        v.yOfHour(hourOfDay(g.start)),
        v.xOfDay(d + 1) - 2,
        v.yOfHour(hourOfDay(g.end)),
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

  void _paintBars(Canvas canvas) {
    for (final b in bars) {
      final color = b.project.color;
      final done = b.task.done;
      final rr = RRect.fromRectAndRadius(b.rect, const Radius.circular(6));
      canvas.drawRRect(
        rr,
        Paint()..color = color.withValues(alpha: done ? 0.35 : 0.95),
      );
      if (b.task.autoPlaced && !done && b.rect.width > 8 && b.rect.height > 8) {
        canvas.drawRRect(
          rr.deflate(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = Colors.white.withValues(alpha: 0.7),
        );
      }
      if (b.rect.height > 16 && b.rect.width > 28) {
        final dark =
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
                : (dark ? Colors.white : Colors.black87),
            decoration: done ? TextDecoration.lineThrough : null,
          ),
          b.rect.width - 8,
          maxLines: ((b.rect.height - 6) / 14).floor().clamp(1, 6),
        );
      }
    }
  }

  void _paintNow(Canvas canvas) {
    final v = viewport;
    final d = dayNumber(now);
    final y = v.yOfHour(hourOfDay(now));
    final p = Paint()
      ..color = scheme.error
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(v.xOfDay(d), y), Offset(v.xOfDay(d + 1), y), p);
    canvas.drawCircle(Offset(v.xOfDay(d), y), 3.5, p);
  }

  void _paintHeader(Canvas canvas, Size size, Paint grid) {
    final v = viewport;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(_gutter, 0, size.width - _gutter, _header));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, _header),
      Paint()..color = scheme.surface,
    );
    final w = v.columnWidth;
    final today = dayNumber(now);
    for (var d = v.firstDay; d <= v.lastDay; d++) {
      final date = dateOfDay(d);
      final x = v.xOfDay(d);
      canvas.drawLine(Offset(x, 22), Offset(x, _header), grid);
      final isToday = d == today;
      final weekend = date.weekday >= 6;
      final label = w >= 70
          ? DateFormat('EEE').format(date)
          : DateFormat('EEEEE').format(date);
      _text(
        canvas,
        label,
        Offset(x + 4, 24),
        TextStyle(
          fontSize: 10,
          color: weekend
              ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
              : scheme.onSurfaceVariant,
        ),
        w - 8,
      );
      if (isToday) {
        canvas.drawCircle(
          Offset(x + w / 2 + (w >= 70 ? 0 : 0), 43),
          10,
          Paint()..color = scheme.primary,
        );
      }
      final numStyle = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isToday ? scheme.onPrimary : scheme.onSurface,
      );
      final tp = _layout('${date.day}', numStyle, w);
      tp.paint(canvas, Offset(x + (w - tp.width) / 2, 43 - tp.height / 2));
    }
    // month band: label at each 1st and at the first visible day
    var lastLabelRight = -1e9;
    for (var d = v.firstDay; d <= v.lastDay; d++) {
      final date = dateOfDay(d);
      if (date.day != 1 && d != v.firstDay) continue;
      final startX = v.xOfDay(d);
      final nextFirst = DateTime(date.year, date.month + 1);
      final endX = v.xOfDay(dayNumber(nextFirst));
      final x = startX < _gutter + 4 ? _gutter + 4 : startX + 4;
      final room = endX - x - 4;
      if (room < 30 || x < lastLabelRight) continue;
      final tp = _layout(
        DateFormat(room > 90 ? 'MMMM yyyy' : 'MMM yy').format(date),
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        room,
      );
      tp.paint(canvas, Offset(x, 3));
      lastLabelRight = x + tp.width + 8;
    }
    canvas.restore();
  }

  void _paintGutter(Canvas canvas, Size size, Paint grid) {
    final v = viewport;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, _header, _gutter, size.height - _header));
    canvas.drawRect(
      Rect.fromLTWH(0, _header, _gutter, size.height - _header),
      Paint()..color = scheme.surface,
    );
    final step = _hourStep(v.hourHeight);
    for (var h = 0; h < 24; h += step) {
      final y = v.yOfHour(h.toDouble());
      _text(
        canvas,
        '${h.toString().padLeft(2, '0')}:00',
        Offset(3, y + 2),
        TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
        _gutter - 4,
      );
    }
    canvas.restore();
  }

  int _hourStep(double hourHeight) =>
      hourHeight >= 34 ? 1 : (hourHeight >= 17 ? 2 : 3);

  TextPainter _layout(
    String s,
    TextStyle style,
    double maxW, {
    int maxLines = 1,
  }) => TextPainter(
    text: TextSpan(text: s, style: style),
    maxLines: maxLines,
    ellipsis: '…',
    textDirection: ui.TextDirection.ltr,
  )..layout(maxWidth: maxW < 1 ? 1 : maxW);

  void _text(
    Canvas canvas,
    String s,
    Offset at,
    TextStyle style,
    double maxW, {
    int maxLines = 1,
  }) {
    if (maxW <= 0) return;
    _layout(s, style, maxW, maxLines: maxLines).paint(canvas, at);
  }

  @override
  bool shouldRepaint(MapPainter old) => true;
}
