import 'dart:math' as math;

import 'habit_profile.dart';
import 'models.dart';

/// A half-open time interval [start, end).
typedef Span = ({DateTime start, DateTime end});

class Placement {
  const Placement(this.projectId, this.taskId, this.start, this.end);
  final String projectId;
  final String taskId;
  final DateTime start;
  final DateTime end;
}

class Unplaced {
  const Unplaced(this.projectId, this.task, this.reason);
  final String projectId;
  final PlanTask task;
  final String reason;
}

class PlanResult {
  const PlanResult(this.placed, this.unplaced);
  final List<Placement> placed;
  final List<Unplaced> unplaced;
}

const _grid = 15; // minutes
const minUsefulGapMinutes = 30;

DateTime _ceilTo(DateTime t, int step) {
  final m = t.minute % step;
  final base = DateTime(t.year, t.month, t.day, t.hour, t.minute);
  return m == 0 && t.second == 0 && t.millisecond == 0
      ? base
      : base.add(Duration(minutes: step - m));
}

DateTime _ceilToGrid(DateTime t) => _ceilTo(t, _grid);

/// The working windows (one per working day) between [from] and [to].
List<Span> workingWindows(HabitProfile p, DateTime from, DateTime to) {
  final out = <Span>[];
  var day = DateTime(from.year, from.month, from.day);
  while (day.isBefore(to)) {
    if (p.workDays.contains(day.weekday)) {
      var s = DateTime(day.year, day.month, day.day, p.workStartHour);
      final e = DateTime(day.year, day.month, day.day, p.workEndHour);
      if (s.isBefore(from)) s = from;
      if (e.isAfter(s)) out.add((start: s, end: e.isAfter(to) ? to : e));
    }
    day = DateTime(day.year, day.month, day.day + 1);
  }
  return out;
}

/// Free gaps inside [windows] once [busy] spans are removed.
List<Span> freeGaps(List<Span> windows, List<Span> busy) {
  final sorted = [...busy]..sort((a, b) => a.start.compareTo(b.start));
  final gaps = <Span>[];
  for (final w in windows) {
    var cursor = w.start;
    for (final b in sorted) {
      if (!b.end.isAfter(cursor) || !b.start.isBefore(w.end)) continue;
      if (b.start.isAfter(cursor)) gaps.add((start: cursor, end: b.start));
      if (b.end.isAfter(cursor)) cursor = b.end;
    }
    if (w.end.isAfter(cursor)) gaps.add((start: cursor, end: w.end));
  }
  return gaps;
}

/// Places flexible tasks into the free time of a working week so that little
/// time is wasted: earlier beats later, urgent beats relaxed, your productive
/// hours beat your weak ones, and tasks are packed tightly against other
/// commitments instead of leaving slivers too short to use.
class AutoPlanner {
  const AutoPlanner();

  PlanResult plan({
    required List<({String projectId, PlanTask task})> flexible,
    required List<Span> busy,
    required DateTime now,
    required HabitProfile profile,
    int horizonDays = 14,
  }) {
    final from = _ceilToGrid(now);
    final to = DateTime(now.year, now.month, now.day + horizonDays);
    final windows = workingWindows(profile, from, to);
    final occupied = [...busy];
    final buffer = Duration(minutes: profile.bufferMinutes);

    final order = [...flexible]
      ..sort((a, b) {
        final da = a.task.deadline, db = b.task.deadline;
        if (da != null || db != null) {
          if (da == null) return 1;
          if (db == null) return -1;
          final c = da.compareTo(db);
          if (c != 0) return c;
        }
        final p = b.task.priority.compareTo(a.task.priority);
        if (p != 0) return p;
        return b.task.estimateMinutes.compareTo(a.task.estimateMinutes);
      });

    final placed = <Placement>[];
    final unplaced = <Unplaced>[];

    for (final item in order) {
      final task = item.task;
      final len = Duration(minutes: math.max(task.estimateMinutes, _grid));
      final best = _bestSlot(
        task,
        len,
        windows,
        occupied,
        buffer,
        profile,
        from,
      );
      if (best == null) {
        final fitsAnyDay = windows.any((w) => w.end.difference(w.start) >= len);
        unplaced.add(
          Unplaced(
            item.projectId,
            task,
            !fitsAnyDay
                ? 'Longer than any free working window: split it into smaller tasks'
                : task.deadline != null
                ? 'No free slot before the deadline'
                : 'No free time in the next $horizonDays days',
          ),
        );
        continue;
      }
      final span = (start: best, end: best.add(len));
      occupied.add(span);
      placed.add(Placement(item.projectId, task.id, span.start, span.end));
    }
    return PlanResult(placed, unplaced);
  }

  DateTime? _bestSlot(
    PlanTask task,
    Duration len,
    List<Span> windows,
    List<Span> occupied,
    Duration buffer,
    HabitProfile profile,
    DateTime from,
  ) {
    final priorityFactor = switch (task.priority) {
      2 => 1.6,
      0 => 0.6,
      _ => 1.0,
    };
    DateTime? best;
    var bestScore = double.negativeInfinity;

    for (final w in windows) {
      final candidates = <DateTime>{};
      for (
        var t = _ceilToGrid(w.start);
        !t.add(len).isAfter(w.end);
        t = t.add(const Duration(minutes: _grid))
      ) {
        candidates.add(t);
      }
      // Also try to sit right behind each existing commitment.
      for (final o in occupied) {
        final t = _ceilTo(o.end.add(buffer), 5);
        if (!t.isBefore(w.start) && !t.add(len).isAfter(w.end)) {
          candidates.add(t);
        }
      }

      for (final s in candidates) {
        final e = s.add(len);
        if (task.deadline != null && e.isAfter(task.deadline!)) continue;
        if (occupied.any(
          (o) =>
              s.isBefore(o.end.add(buffer)) && e.add(buffer).isAfter(o.start),
        )) {
          continue;
        }

        // How good are these hours for you?
        var hourScore = 0.0;
        var n = 0;
        for (
          var t = s;
          t.isBefore(e);
          t = t.add(const Duration(minutes: _grid))
        ) {
          hourScore += profile.weightAt(t.hour);
          n++;
        }
        hourScore /= math.max(n, 1);

        // Sooner is better, more so for urgent tasks.
        final daysAway = s.difference(from).inMinutes / (24 * 60);
        var score = hourScore - daysAway * 0.35 * priorityFactor;

        // Wasted-time penalty: a leftover gap that is too short to be useful.
        var before = w.start, after = w.end;
        for (final o in occupied) {
          if (!o.end.isAfter(s) && o.end.isAfter(before)) before = o.end;
          if (!o.start.isBefore(e) && o.start.isBefore(after)) after = o.start;
        }
        for (final gap in [s.difference(before), after.difference(e)]) {
          // Starts behind a commitment snap up to 5 minutes; allow that slack
          // but nothing more, so a 15-minute grid gap is not "snug".
          if (gap < buffer + const Duration(minutes: 5)) {
            score += 0.25; // snug fit
          } else if (gap.inMinutes < minUsefulGapMinutes) {
            score -= 0.7; // a sliver nothing else fits in
          }
        }

        if (score > bestScore) {
          bestScore = score;
          best = s;
        }
      }
    }
    return best;
  }
}

/// Commitments that occupy time: every scheduled, unfinished task.
List<Span> busySpans(Iterable<Project> projects) => [
  for (final p in projects)
    for (final t in p.tasks)
      if (t.scheduled && !t.done) (start: t.start!, end: t.end!),
];

/// A gap is wasted when it is longer than the deliberate break between tasks
/// but still too short to do anything in.
bool isWastedGap(Span g, HabitProfile profile) {
  final m = g.end.difference(g.start).inMinutes;
  return m > profile.bufferMinutes && m < minUsefulGapMinutes;
}

class TimeStats {
  const TimeStats(this.usableMinutes, this.wastedMinutes);

  /// Free time in gaps long enough to do something in.
  final int usableMinutes;

  /// Free time stuck in gaps too short to be useful.
  final int wastedMinutes;
}

/// Free working time between [from] and [to], split into usable and wasted.
TimeStats timeStats(
  List<Span> busy,
  HabitProfile profile,
  DateTime from,
  DateTime to,
) {
  var usable = 0, wasted = 0;
  for (final g in freeGaps(workingWindows(profile, from, to), busy)) {
    final m = g.end.difference(g.start).inMinutes;
    if (m >= minUsefulGapMinutes) {
      usable += m;
    } else if (isWastedGap(g, profile)) {
      wasted += m;
    }
  }
  return TimeStats(usable, wasted);
}
