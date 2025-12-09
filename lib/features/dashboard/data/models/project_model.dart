import 'package:isar/isar.dart';
import 'package:timewise_application/features/dashboard/domain/entities/entities.dart';

part 'project_model.g.dart';

@collection
class ProjectModel {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true)
  late String id;

  late String title;
  String? description;
  late DateTime createdAt;
  DateTime? dueDate;
  late bool isCompleted;

  @Enumerated(EnumType.ordinal)
  late ProjectColor color;

  // Convert to domain entity
  Project toEntity(List<Task> tasks) {
    return Project(
      id: id,
      title: title,
      description: description,
      createdAt: createdAt,
      dueDate: dueDate,
      isCompleted: isCompleted,
      tasks: tasks,
      color: color,
    );
  }

  // Create from domain entity
  static ProjectModel fromEntity(Project project) {
    return ProjectModel()
      ..id = project.id
      ..title = project.title
      ..description = project.description
      ..createdAt = project.createdAt
      ..dueDate = project.dueDate
      ..isCompleted = project.isCompleted
      ..color = project.color;
  }
}
