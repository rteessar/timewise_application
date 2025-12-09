import 'package:isar/isar.dart';
import 'package:timewise_application/features/dashboard/data/models/models.dart';
import 'package:timewise_application/features/dashboard/domain/entities/entities.dart';
import 'package:timewise_application/features/dashboard/domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  final Isar _isar;

  TaskRepositoryImpl(this._isar);

  @override
  Future<List<Task>> getTasksByProjectId(String projectId) async {
    final models = await _isar.taskModels
        .filter()
        .projectIdEqualTo(projectId)
        .findAll();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<List<Task>> getTasksInDateRange(DateTime start, DateTime end) async {
    final models = await _isar.taskModels
        .filter()
        .startTimeIsNotNull()
        .startTimeGreaterThan(start)
        .startTimeLessThan(end)
        .findAll();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<Task?> getTaskById(String id) async {
    final model = await _isar.taskModels.filter().idEqualTo(id).findFirst();
    return model?.toEntity();
  }

  @override
  Future<void> createTask(Task task) async {
    await _isar.writeTxn(() async {
      await _isar.taskModels.put(TaskModel.fromEntity(task));
    });
  }

  @override
  Future<void> updateTask(Task task) async {
    await _isar.writeTxn(() async {
      final existing = await _isar.taskModels
          .filter()
          .idEqualTo(task.id)
          .findFirst();
      if (existing != null) {
        final updated = TaskModel.fromEntity(task)..isarId = existing.isarId;
        await _isar.taskModels.put(updated);
      }
    });
  }

  @override
  Future<void> deleteTask(String id) async {
    await _isar.writeTxn(() async {
      await _isar.taskModels.filter().idEqualTo(id).deleteAll();
    });
  }

  @override
  Future<void> completeTask(String id) async {
    final task = await getTaskById(id);
    if (task != null) {
      await updateTask(task.copyWith(isCompleted: true));
    }
  }

  @override
  Stream<List<Task>> watchTasksByProjectId(String projectId) {
    return _isar.taskModels
        .filter()
        .projectIdEqualTo(projectId)
        .watch(fireImmediately: true)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }
}
