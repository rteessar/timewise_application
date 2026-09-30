import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'timeline_layout.dart';

enum _Unit { hour, day, week, month }

class TimelinePainter extends CustomPainter {
  TimelinePainter({
    required this.layout,
    required this.leftDay,
    required this.pixelsPerDay,
    required this.scrollY,
    required this.now,
    required this.scheme,
    this.selectedTaskId,
  });

  final TimelineLayout layout;
  final double leftDay;
  final double pixelsPerDay;
  final double scrollY;
  final DateTime now;
  final ColorScheme scheme;
  final String? selectedTaskId;

  double _x(DateTime t) => (dayOf(t) - leftDay) * pixelsPerDay;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final rightDay = leftDay + size.width / pixelsPerDay;
    final from = timeOfDay(leftDay);
    final to = timeOfDay(rightDay);

    // --- content layer (scrolls vertically) ---
    canvas.save();
    canvas.translate(0, -scrollY);
    _paintLanes(canvas, size);
    _paintGrid(canvas, size, from, to, gridOnly: true);
    _paintBars(canvas, size);
    _paintNow(canvas, size, headerOnly: false);
    canvas.restore();

    // --- sticky header ---
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, kHeaderHeight),
      Paint()..color = scheme.surface,
    );
    _paintGrid(canvas, size, from, to, gridOnly: false);
    _paintNow(canvas, size, headerOnly: true);
    canvas.drawLine(
      const Offset(0, kHeaderHeight),
      Offset(size.width, kHeaderHeight),
      Paint()..color = scheme.outlineVariant,
    );

    // --- sticky lane labels ---
    canvas.save();
    canvas.translate(0, -scrollY);
    for (final l in layout.lanes) {
      _label(
        canvas,
        l.project.name.toUpperCase(),
        Offset(10, l.top + 4),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
          color: l.project.color,
        ),
        maxWidth: size.width - 20,
      );
    }
    canvas.restore();
  }

  void _paintLanes(Canvas canvas, Size size) {
    for (var i = 0; i < layout.lanes.length; i++) {
      final l = layout.lanes[i];
      canvas.drawRect(
        Rect.fromLTWH(0, l.top, size.width, l.height),
        Paint()
          ..color = l.project.color.withValues(alpha: i.isEven ? 0.06 : 0.025),
      );
      canvas.drawLine(
        Offset(0, l.bottom),
        Offset(size.width, l.bottom),
        Paint()..color = scheme.outlineVariant.withValues(alpha: 0.6),
      );
    }
  }

  _Unit get _unit {
    if (pixelsPerDay >= 200) return _Unit.hour;
    if (pixelsPerDay >= 24) return _Unit.day;
    if (pixelsPerDay >= 6) return _Unit.week;
    return _Unit.month;
  }

  int get _hourStep {
    if (pixelsPerDay >= 1200) return 1;
    if (pixelsPerDay >= 500) return 3;
    return 6;
  }

  void _paintGrid(
    Canvas canvas,
    Size size,
    DateTime from,
    DateTime to, {
    required bool gridOnly,
  }) {
    final gridPaint = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.45);
    final bottom = gridOnly ? layout.contentHeight + scrollY : kHeaderHeight;
    final top = gridOnly ? kHeaderHeight : kHeaderHeight - 22;

    final unit = _unit;
    var t = _floorTo(from, unit);
    var guard = 0;
    while (t.isBefore(to) && guard++ < 2000) {
      final x = _x(t);
      if (gridOnly) {
        canvas.drawLine(Offset(x, top), Offset(x, bottom), gridPaint);
      } else {
        canvas.drawLine(Offset(x, top), Offset(x, kHeaderHeight), gridPaint);
        _label(
          canvas,
          _minorLabel(t, unit),
          Offset(x + 4, top + 4),
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          maxWidth: math.max(_stepPx(unit) - 6, 0),
        );
      }
      t = _next(t, unit);
    }

    if (!gridOnly) _paintMonthBand(canvas, size, from, to);
  }

  double _stepPx(_Unit u) => switch (u) {
    _Unit.hour => pixelsPerDay / 24 * _hourStep,
    _Unit.day => pixelsPerDay,
    _Unit.week => pixelsPerDay * 7,
    _Unit.month => pixelsPerDay * 30,
  };

  /// Top band with sticky month/year labels.
  void _paintMonthBand(Canvas canvas, Size size, DateTime from, DateTime to) {
    var m = DateTime(from.year, from.month);
    var guard = 0;
    while (m.isBefore(to) && guard++ < 500) {
      final next = DateTime(m.year, m.month + 1);
      final x0 = _x(m);
      final x1 = _x(next);
      canvas.drawLine(
        Offset(x0, 0),
        Offset(x0, 22),
        Paint()..color = scheme.outline.withValues(alpha: 0.6),
      );
      final label = pixelsPerDay < 6
          ? DateFormat('MMM yy').format(m)
          : DateFormat('MMMM yyyy').format(m);
      final lx = math.max(x0 + 6, 6.0);
      final room = x1 - lx - 6;
      if (room > 28) {
        _label(
          canvas,
          label,
          Offset(lx, 4),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          maxWidth: room,
        );
      }
      m = next;
    }
  }

  DateTime _floorTo(DateTime t, _Unit u) => switch (u) {
    _Unit.hour => DateTime(
      t.year,
      t.month,
      t.day,
      (t.hour ~/ _hourStep) * _hourStep,
    ),
    _Unit.day => DateTime(t.year, t.month, t.day),
    _Unit.week => DateTime(t.year, t.month, t.day - (t.weekday - 1)),
    _Unit.month => DateTime(t.year, t.month),
  };

  DateTime _next(DateTime t, _Unit u) => switch (u) {
    _Unit.hour => DateTime(t.year, t.month, t.day, t.hour + _hourStep),
    _Unit.day => DateTime(t.year, t.month, t.day + 1),
    _Unit.week => DateTime(t.year, t.month, t.day + 7),
    _Unit.month => DateTime(t.year, t.month + 1),
  };

  String _minorLabel(DateTime t, _Unit u) => switch (u) {
    _Unit.hour =>
      t.hour == 0
          ? DateFormat('d MMM').format(t)
          : DateFormat('HH:mm').format(t),
    _Unit.day =>
      pixelsPerDay >= 70
          ? DateFormat('EEE d').format(t)
          : DateFormat('d').format(t),
    _Unit.week => DateFormat('d MMM').format(t),
    _Unit.month =>
      t.month == 1 ? DateFormat('yyyy').format(t) : DateFormat('MMM').format(t),
  };

  void _paintBars(Canvas canvas, Size size) {
    for (final b in layout.bars) {
      final r = b.rect;
      if (r.right < -4 || r.left > size.width + 4) continue;
      final color = b.project.color;
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(8));
      final done = b.task.done;
      canvas.drawRRect(
        rr,
        Paint()..color = color.withValues(alpha: done ? 0.35 : 0.92),
      );
      if (b.task.id == selectedTaskId) {
        canvas.drawRRect(
          rr.inflate(2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = scheme.onSurface,
        );
      }
      final labelLeft = math.max(r.left, 0.0) + 8;
      final room = r.right - labelLeft - 6;
      if (room > 14) {
        _label(
          canvas,
          '${done ? '✓ ' : ''}${b.task.title}',
          Offset(labelLeft, r.top + (kBarHeight - 14) / 2),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: done
                ? scheme.onSurface
                : (ThemeData.estimateBrightnessForColor(color) ==
                          Brightness.dark
                      ? Colors.white
                      : Colors.black87),
            decoration: done ? TextDecoration.lineThrough : null,
          ),
          maxWidth: room,
        );
      }
    }
  }

  void _paintNow(Canvas canvas, Size size, {required bool headerOnly}) {
    final x = _x(now);
    if (x < -2 || x > size.width + 2) return;
    final paint = Paint()
      ..color = scheme.error
      ..strokeWidth = 1.5;
    if (headerOnly) {
      canvas.drawCircle(Offset(x, kHeaderHeight - 1), 4, paint);
    } else {
      canvas.drawLine(
        Offset(x, kHeaderHeight),
        Offset(x, layout.contentHeight + scrollY + size.height),
        paint,
      );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at, {
    required TextStyle style,
    required double maxWidth,
  }) {
    if (maxWidth <= 0) return;
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      ellipsis: '…',
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(TimelinePainter old) => true;
}
