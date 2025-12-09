import 'package:isar/isar.dart';
import 'package:timewise_application/features/dashboard/domain/entities/entities.dart';

part 'task_model.g.dart';

@collection
class TaskModel {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  @Index()
  late String projectId;

  late String title;
  String? description;
  late DateTime createdAt;
  DateTime? startTime;
  DateTime? endTime;
  late int estimatedMinutes;
  late bool isCompleted;

  @Enumerated(EnumType.ordinal)
  late TaskPriority priority;

  String? parentTaskId;
  late List<String> subtaskIds;

  Task toEntity() {
    return Task(
      id: id,
      projectId: projectId,
      title: title,
      description: description,
      createdAt: createdAt,
      startTime: startTime,
      endTime: endTime,
      estimatedMinutes: estimatedMinutes,
      isCompleted: isCompleted,
      priority: priority,
      parentTaskId: parentTaskId,
      subtaskIds: subtaskIds,
    );
  }

  static TaskModel fromEntity(Task task) {
    return TaskModel()
      ..id = task.id
      ..projectId = task.projectId
      ..title = task.title
      ..description = task.description
      ..createdAt = task.createdAt
      ..startTime = task.startTime
      ..endTime = task.endTime
      ..estimatedMinutes = task.estimatedMinutes
      ..isCompleted = task.isCompleted
      ..priority = task.priority
      ..parentTaskId = task.parentTaskId
      ..subtaskIds = task.subtaskIds;
  }
}
