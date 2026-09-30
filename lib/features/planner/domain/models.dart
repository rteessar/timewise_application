import 'package:flutter/material.dart';

/// A unit of work. It is either *fixed* (the user chose its time, e.g. a
/// meeting) or *flexible* (only an estimate, deadline and priority are known
/// and the auto-planner finds a slot for it).
@immutable
class PlanTask {
  const PlanTask({
    required this.id,
    required this.title,
    this.start,
    this.end,
    this.estimateMinutes = 60,
    this.deadline,
    this.priority = 1,
    this.fixed = false,
    this.done = false,
    this.autoPlaced = false,
  });

  final String id;
  final String title;
  final DateTime? start;
  final DateTime? end;

  /// How long the task takes. Drives the planner for flexible tasks.
  final int estimateMinutes;

  /// Latest moment the task should finish (flexible tasks only).
  final DateTime? deadline;

  /// 0 = low, 1 = normal, 2 = high.
  final int priority;

  /// True when the user chose the time themselves; the planner never moves it.
  final bool fixed;
  final bool done;

  /// True when the current start/end was chosen by the planner.
  final bool autoPlaced;

  bool get scheduled => start != null && end != null;

  Duration get duration =>
      scheduled ? end!.difference(start!) : Duration(minutes: estimateMinutes);

  bool overlaps(DateTime from, DateTime to) =>
      scheduled && start!.isBefore(to) && end!.isAfter(from);

  PlanTask copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    int? estimateMinutes,
    DateTime? deadline,
    bool clearDeadline = false,
    int? priority,
    bool? fixed,
    bool? done,
    bool? autoPlaced,
  }) => PlanTask(
    id: id,
    title: title ?? this.title,
    start: start ?? this.start,
    end: end ?? this.end,
    estimateMinutes: estimateMinutes ?? this.estimateMinutes,
    deadline: clearDeadline ? null : (deadline ?? this.deadline),
    priority: priority ?? this.priority,
    fixed: fixed ?? this.fixed,
    done: done ?? this.done,
    autoPlaced: autoPlaced ?? this.autoPlaced,
  );

  /// Back to the inbox: keeps everything except the time slot.
  PlanTask unscheduled() => PlanTask(
    id: id,
    title: title,
    estimateMinutes: estimateMinutes,
    deadline: deadline,
    priority: priority,
    done: done,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': start?.toIso8601String(),
    'end': end?.toIso8601String(),
    'estimate': estimateMinutes,
    'deadline': deadline?.toIso8601String(),
    'priority': priority,
    'fixed': fixed,
    'done': done,
    'autoPlaced': autoPlaced,
  };

  factory PlanTask.fromJson(Map<String, dynamic> j) {
    DateTime? d(String k) =>
        j[k] == null ? null : DateTime.parse(j[k] as String);
    final start = d('start');
    final end = d('end');
    return PlanTask(
      id: j['id'] as String,
      title: j['title'] as String,
      start: start,
      end: end,
      // v1 data had no estimate/fixed: derive them from the stored times.
      estimateMinutes:
          j['estimate'] as int? ??
          (start != null && end != null ? end.difference(start).inMinutes : 60),
      deadline: d('deadline'),
      priority: j['priority'] as int? ?? 1,
      fixed: j['fixed'] as bool? ?? start != null,
      done: j['done'] as bool? ?? false,
      autoPlaced: j['autoPlaced'] as bool? ?? false,
    );
  }
}

/// A project is a lane on the map, holding tasks.
@immutable
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.colorValue,
    this.tasks = const [],
  });

  final String id;
  final String name;
  final int colorValue;
  final List<PlanTask> tasks;

  Color get color => Color(colorValue);

  double get progress =>
      tasks.isEmpty ? 0 : tasks.where((t) => t.done).length / tasks.length;

  Project copyWith({String? name, int? colorValue, List<PlanTask>? tasks}) =>
      Project(
        id: id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        tasks: tasks ?? this.tasks,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'color': colorValue,
    'tasks': tasks.map((t) => t.toJson()).toList(),
  };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
    id: j['id'] as String,
    name: j['name'] as String,
    colorValue: j['color'] as int,
    tasks: (j['tasks'] as List<dynamic>? ?? [])
        .map((t) => PlanTask.fromJson(t as Map<String, dynamic>))
        .toList(),
  );
}

/// Palette offered when composing a project.
const projectPalette = <int>[
  0xFF6366F1,
  0xFF8B5CF6,
  0xFFEC4899,
  0xFFEF4444,
  0xFFF59E0B,
  0xFF22C55E,
  0xFF14B8A6,
  0xFF3B82F6,
];
