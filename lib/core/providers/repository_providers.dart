import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timewise_application/core/providers/database_provider.dart';
import 'package:timewise_application/features/dashboard/data/data.dart';
import 'package:timewise_application/features/dashboard/domain/repositories/project_repository.dart';
import 'package:timewise_application/features/dashboard/domain/repositories/task_repository.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return ProjectRepositoryImpl(isar);
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return TaskRepositoryImpl(isar);
});
