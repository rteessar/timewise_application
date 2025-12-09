import 'package:timewise_application/features/dashboard/domain/entities/entities.dart';

abstract class ProjectRepository {
  Future<List<Project>> getAllProjects();
  Future<Project?> getProjectById(String id);
  Future<void> createProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(String id);
  Stream<List<Project>> watchAllProjects();
}
