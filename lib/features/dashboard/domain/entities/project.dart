import 'package:freezed_annotation/freezed_annotation.dart';

part 'project.freezed.dart';
part 'project.g.dart';

@freezed
class Project with _$Project {
  const factory Project({
    required String id,
    required String title,
    String? description,
    required DateTime createdAt,
    DateTime? dueDate,
    @Default(false) bool isCompleted,
    @Default([]) List<dynamic> tasks,
    @Default(ProjectColor.blue) ProjectColor color,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);
}

enum ProjectColor { blue, purple, green, orange, red, teal }
