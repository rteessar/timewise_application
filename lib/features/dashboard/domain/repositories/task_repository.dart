import 'package:timewise_application/features/dashboard/domain/entities/entities.dart';

abstract class TaskRepository {
  Future<List<Task>> getTasksByProjectId(String projectId);
  Future<List<Task>> getTasksInDateRange(DateTime start, DateTime end);
  Future<Task?> getTaskById(String id);
  Future<void> createTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String id);
  Future<void> completeTask(String id);
  Stream<List<Task>> watchTasksByProjectId(String projectId);
}
