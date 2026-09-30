import 'dart:ui';

import '../../planner/domain/models.dart';
import 'map_viewport.dart';

class MapBar {
  const MapBar(this.project, this.task, this.rect);
  final Project project;
  final PlanTask task;
  final Rect rect;
}

/// Rectangles of every visible task. A task that crosses midnight is split
/// into one bar per day so it reads correctly in each column.
List<MapBar> layoutBars(List<Project> projects, MapViewport v) {
  final bars = <MapBar>[];
  final first = v.firstDay, last = v.lastDay;
  for (final p in projects) {
    for (final t in p.tasks) {
      if (!t.scheduled) continue;
      final startDay = dayNumber(t.start!);
      // An end exactly at midnight belongs to the previous day.
      final endDay = dayNumber(
        t.end!.subtract(const Duration(milliseconds: 1)),
      );
      if (endDay < first || startDay > last) continue;
      for (
        var d = startDay < first ? first : startDay;
        d <= endDay && d <= last;
        d++
      ) {
        final from = d == startDay ? hourOfDay(t.start!) : 0.0;
        final to = dayNumber(t.end!) == d ? hourOfDay(t.end!) : 24.0;
        bars.add(
          MapBar(
            p,
            t,
            Rect.fromLTRB(
              v.xOfDay(d) + 2,
              v.yOfHour(from),
              v.xOfDay(d + 1) - 2,
              v.yOfHour(to),
            ),
          ),
        );
      }
    }
  }
  return bars;
}

MapBar? barAt(List<MapBar> bars, Offset p) {
  for (final b in bars.reversed) {
    if (b.rect.contains(p)) return b;
  }
  return null;
}
