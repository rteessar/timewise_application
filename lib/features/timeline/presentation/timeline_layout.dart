import 'dart:math' as math;
import 'dart:ui';

import '../../planner/domain/models.dart';

const double kHeaderHeight = 56;
const double kBarHeight = 30;
const double kBarGap = 6;
const double kLanePadding = 14;
const double kMinLaneHeight = 84;

/// Time <-> x conversions. A "day" value is fractional days since the epoch,
/// so a viewport is fully described by (leftDay, pixelsPerDay).
double dayOf(DateTime t) =>
    t.millisecondsSinceEpoch / Duration.millisecondsPerDay;

DateTime timeOfDay(double day) => DateTime.fromMillisecondsSinceEpoch(
  (day * Duration.millisecondsPerDay).round(),
);

class BarRect {
  const BarRect(this.project, this.task, this.rect);
  final Project project;
  final PlanTask task;
  final Rect rect; // x in viewport space, y in unscrolled content space
}

class LaneRect {
  const LaneRect(this.project, this.top, this.height);
  final Project project;
  final double top;
  final double height;
  double get bottom => top + height;
}

/// Positions every project lane and task bar for a given zoom. The same
/// object drives painting and hit-testing so they can never disagree.
class TimelineLayout {
  TimelineLayout._(this.lanes, this.bars, this.contentHeight);

  final List<LaneRect> lanes;
  final List<BarRect> bars;
  final double contentHeight;

  factory TimelineLayout.build(
    List<Project> projects, {
    required double leftDay,
    required double pixelsPerDay,
  }) {
    final lanes = <LaneRect>[];
    final bars = <BarRect>[];
    var y = kHeaderHeight;
    for (final p in projects) {
      final sorted = [...p.tasks]..sort((a, b) => a.start.compareTo(b.start));
      final rowEnds = <double>[];
      final placed = <(PlanTask, double, double, int)>[];
      for (final t in sorted) {
        final x0 = (dayOf(t.start) - leftDay) * pixelsPerDay;
        final w = math.max(
          (dayOf(t.end) - dayOf(t.start)) * pixelsPerDay,
          28.0,
        );
        var row = rowEnds.indexWhere((e) => e + 4 <= x0);
        if (row < 0) {
          row = rowEnds.length;
          rowEnds.add(0);
        }
        rowEnds[row] = x0 + w;
        placed.add((t, x0, w, row));
      }
      final rows = math.max(rowEnds.length, 1);
      final h = math.max(
        kMinLaneHeight,
        kLanePadding * 2 + rows * (kBarHeight + kBarGap),
      );
      for (final (t, x0, w, row) in placed) {
        bars.add(
          BarRect(
            p,
            t,
            Rect.fromLTWH(
              x0,
              y + kLanePadding + row * (kBarHeight + kBarGap),
              w,
              kBarHeight,
            ),
          ),
        );
      }
      lanes.add(LaneRect(p, y, h));
      y += h;
    }
    return TimelineLayout._(lanes, bars, y);
  }

  BarRect? barAt(Offset contentPoint) {
    for (final b in bars.reversed) {
      if (b.rect.inflate(3).contains(contentPoint)) return b;
    }
    return null;
  }

  LaneRect? laneAt(double contentY) {
    for (final l in lanes) {
      if (contentY >= l.top && contentY < l.bottom) return l;
    }
    return null;
  }
}
