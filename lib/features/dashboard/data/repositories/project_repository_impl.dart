import 'package:isar/isar.dart';
import 'package:timewise_application/features/dashboard/data/models/models.dart';
import 'package:timewise_application/features/dashboard/domain/entities/entities.dart';
import 'package:timewise_application/features/dashboard/domain/repositories/project_repository.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final Isar _isar;

  ProjectRepositoryImpl(this._isar);

  @override
  Future<List<Project>> getAllProjects() async {
    final projectModels = await _isar.projectModels.where().findAll();
    final projects = <Project>[];

    for (final model in projectModels) {
      final taskModels = await _isar.taskModels
          .filter()
          .projectIdEqualTo(model.id)
          .findAll();
      final tasks = taskModels.map((t) => t.toEntity()).toList();
      projects.add(model.toEntity(tasks));
    }

    return projects;
  }

  @override
  Future<Project?> getProjectById(String id) async {
    final model = await _isar.projectModels.filter().idEqualTo(id).findFirst();
    if (model == null) return null;

    final taskModels = await _isar.taskModels
        .filter()
        .projectIdEqualTo(id)
        .findAll();
    final tasks = taskModels.map((t) => t.toEntity()).toList();

    return model.toEntity(tasks);
  }

  @override
  Future<void> createProject(Project project) async {
    await _isar.writeTxn(() async {
      await _isar.projectModels.put(ProjectModel.fromEntity(project));
    });
  }

  @override
  Future<void> updateProject(Project project) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.projectModels
          .filter()
          .idEqualTo(project.id)
          .findFirst();
      if (existing != null) {
        final updated = ProjectModel.fromEntity(project)..isarId = existing.isarId;
        await _isar.projectModels.put(updated);
      }
    });
  }

  @override
  Future<void> deleteProject(String id) async {
    await _isar.writeTxn(() async {
      await _isar.projectModels.filter().idEqualTo(id).deleteAll();
      await _isar.taskModels.filter().projectIdEqualTo(id).deleteAll();
    });
  }

  @override
  Stream<List<Project>> watchAllProjects() {
    return _isar.projectModels
        .where()
        .watch(fireImmediately: true)
        .asyncMap((_) => getAllProjects());
  }
}
