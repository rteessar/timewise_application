import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// What TimeWise knows about how you work: the hours you are available and a
/// learned weight per hour of the day (1 = neutral, higher = you tend to get
/// things done then). The weights drift with your behaviour, see
/// [recordCompletion] and [recordMove].
@immutable
class HabitProfile {
  HabitProfile({
    this.workStartHour = 9,
    this.workEndHour = 18,
    Set<int>? workDays,
    this.bufferMinutes = 10,
    List<double>? hourWeights,
    this.signals = 0,
  }) : workDays = workDays ?? {1, 2, 3, 4, 5},
       hourWeights = hourWeights ?? List.filled(24, 1.0);

  final int workStartHour;
  final int workEndHour;

  /// DateTime weekday numbers: Monday = 1 ... Sunday = 7.
  final Set<int> workDays;

  /// Breathing room kept between planned tasks.
  final int bufferMinutes;
  final List<double> hourWeights;

  /// How many observations the weights are based on.
  final int signals;

  static const minWeight = 0.2;
  static const maxWeight = 2.0;

  double weightAt(int hour) => hourWeights[hour.clamp(0, 23)];

  HabitProfile copyWith({
    int? workStartHour,
    int? workEndHour,
    Set<int>? workDays,
    int? bufferMinutes,
    List<double>? hourWeights,
    int? signals,
  }) => HabitProfile(
    workStartHour: workStartHour ?? this.workStartHour,
    workEndHour: workEndHour ?? this.workEndHour,
    workDays: workDays ?? this.workDays,
    bufferMinutes: bufferMinutes ?? this.bufferMinutes,
    hourWeights: hourWeights ?? this.hourWeights,
    signals: signals ?? this.signals,
  );

  HabitProfile _nudge(Map<int, double> deltas) {
    final w = [...hourWeights];
    deltas.forEach((h, d) {
      w[h] = math.min(maxWeight, math.max(minWeight, w[h] + d));
    });
    return copyWith(hourWeights: w, signals: signals + 1);
  }

  /// A planned task was completed during its slot: you work well then.
  HabitProfile recordCompletion(int hour) => _nudge({hour: 0.12});

  /// You moved an auto-placed task from [fromHour] to [toHour]: the planner
  /// guessed wrong, so steer away from the first and towards the second.
  HabitProfile recordMove(int fromHour, int toHour) {
    if (fromHour == toHour) return this;
    return _nudge({fromHour: -0.12, toHour: 0.15});
  }

  HabitProfile resetLearning() =>
      copyWith(hourWeights: List.filled(24, 1.0), signals: 0);

  Map<String, dynamic> toJson() => {
    'workStart': workStartHour,
    'workEnd': workEndHour,
    'workDays': workDays.toList()..sort(),
    'buffer': bufferMinutes,
    'weights': hourWeights,
    'signals': signals,
  };

  factory HabitProfile.fromJson(Map<String, dynamic> j) => HabitProfile(
    workStartHour: j['workStart'] as int? ?? 9,
    workEndHour: j['workEnd'] as int? ?? 18,
    workDays: (j['workDays'] as List<dynamic>?)?.cast<int>().toSet(),
    bufferMinutes: j['buffer'] as int? ?? 10,
    hourWeights: (j['weights'] as List<dynamic>?)
        ?.map((e) => (e as num).toDouble())
        .toList(),
    signals: j['signals'] as int? ?? 0,
  );
}
