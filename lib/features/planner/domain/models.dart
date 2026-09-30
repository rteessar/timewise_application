import 'package:flutter/material.dart';

/// A unit of work placed on the timeline map.
@immutable
class PlanTask {
  const PlanTask({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.done = false,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool done;

  Duration get duration => end.difference(start);

  bool overlaps(DateTime from, DateTime to) =>
      start.isBefore(to) && end.isAfter(from);

  PlanTask copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    bool? done,
  }) => PlanTask(
    id: id,
    title: title ?? this.title,
    start: start ?? this.start,
    end: end ?? this.end,
    done: done ?? this.done,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'done': done,
  };

  factory PlanTask.fromJson(Map<String, dynamic> j) => PlanTask(
    id: j['id'] as String,
    title: j['title'] as String,
    start: DateTime.parse(j['start'] as String),
    end: DateTime.parse(j['end'] as String),
    done: j['done'] as bool? ?? false,
  );
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
