import 'dart:ui';

import '../../planner/domain/models.dart';

const double kTimeColWidth = 38;
const int kFirstHour = 6;
const int kLastHour = 23; // exclusive end of the grid

class WeekBar {
  const WeekBar(this.project, this.task, this.rect);
  final Project project;
  final PlanTask task;
  final Rect rect;
}

/// Geometry of the week map: which rectangle every task occupies.
class WeekLayout {
  WeekLayout({
    required this.days,
    required this.width,
    required this.hourHeight,
    required List<Project> projects,
  }) : columnWidth = (width - kTimeColWidth) / days.length {
    for (final p in projects) {
      for (final t in p.tasks) {
        if (!t.scheduled) continue;
        for (var i = 0; i < days.length; i++) {
          final d = days[i];
          final dayStart = DateTime(d.year, d.month, d.day);
          final dayEnd = DateTime(d.year, d.month, d.day + 1);
          if (!t.start!.isBefore(dayEnd) || !t.end!.isAfter(dayStart)) continue;
          final s = t.start!.isBefore(dayStart) ? dayStart : t.start!;
          final e = t.end!.isAfter(dayEnd) ? dayEnd : t.end!;
          final rect = Rect.fromLTRB(
            columnX(i) + 2,
            yOf(s),
            columnX(i) + columnWidth - 2,
            yOf(e),
          );
          bars.add(WeekBar(p, t, rect));
        }
      }
    }
  }

  final List<DateTime> days;
  final double width;
  final double hourHeight;
  final double columnWidth;
  final bars = <WeekBar>[];

  double get height => (kLastHour - kFirstHour) * hourHeight;

  double columnX(int i) => kTimeColWidth + i * columnWidth;

  double yOf(DateTime t) =>
      ((t.hour + t.minute / 60) - kFirstHour) * hourHeight;

  /// The day column at [x], or -1.
  int columnAt(double x) {
    if (x < kTimeColWidth) return -1;
    final i = ((x - kTimeColWidth) / columnWidth).floor();
    return i >= 0 && i < days.length ? i : -1;
  }

  DateTime timeAt(int column, double y) {
    final hours = kFirstHour + y / hourHeight;
    final d = days[column];
    final minutes = (hours * 60 / 30).floor() * 30;
    return DateTime(d.year, d.month, d.day, 0, minutes);
  }

  WeekBar? barAt(Offset p) {
    for (final b in bars.reversed) {
      if (b.rect.contains(p)) return b;
    }
    return null;
  }
}
