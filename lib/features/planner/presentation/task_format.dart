import 'package:intl/intl.dart';

import '../domain/models.dart';

final _dt = DateFormat('EEE d MMM, HH:mm');
final _d = DateFormat('EEE d MMM');

String formatMinutes(int m) {
  if (m < 60) return '${m}m';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '${h}h' : '${h}h ${r}m';
}

/// One line describing when a task happens (or what it still needs).
String taskWhen(PlanTask t) {
  if (t.scheduled) {
    final sameDay = DateUtils2.sameDay(t.start!, t.end!);
    return sameDay
        ? '${_dt.format(t.start!)} – ${DateFormat('HH:mm').format(t.end!)}'
        : '${_dt.format(t.start!)} → ${_dt.format(t.end!)}';
  }
  final parts = [
    formatMinutes(t.estimateMinutes),
    if (t.deadline != null) 'due ${_d.format(t.deadline!)}',
  ];
  return parts.join(' · ');
}

abstract final class DateUtils2 {
  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

const priorityLabels = ['Low', 'Normal', 'High'];
