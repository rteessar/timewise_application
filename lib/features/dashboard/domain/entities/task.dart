import 'package:freezed_annotation/freezed_annotation.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required String projectId,
    required String title,
    String? description,
    required DateTime createdAt,
    DateTime? startTime,
    DateTime? endTime,
    @Default(0) int estimatedMinutes,
    @Default(false) bool isCompleted,
    @Default(TaskPriority.medium) TaskPriority priority,
    String? parentTaskId,
    @Default([]) List<String> subtaskIds,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}

enum TaskPriority { low, medium, high, urgent }
