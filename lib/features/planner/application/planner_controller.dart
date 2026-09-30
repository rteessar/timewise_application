import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../data/planner_repository.dart';
import '../domain/models.dart';

/// Overridden in `main` once SharedPreferences has loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);

final plannerRepositoryProvider = Provider(
  (ref) => PlannerRepository(ref.watch(sharedPreferencesProvider)),
);

final plannerProvider = NotifierProvider<PlannerController, List<Project>>(
  PlannerController.new,
);

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

class PlannerController extends Notifier<List<Project>> {
  @override
  List<Project> build() => ref.watch(plannerRepositoryProvider).load();

  void _set(List<Project> next) {
    state = next;
    ref.read(plannerRepositoryProvider).save(next);
  }

  void upsertProject(Project p) {
    final i = state.indexWhere((e) => e.id == p.id);
    if (i < 0) {
      _set([...state, p]);
    } else {
      _set([...state]..[i] = p);
    }
  }

  void deleteProject(String id) =>
      _set(state.where((p) => p.id != id).toList());

  void upsertTask(String projectId, PlanTask t) {
    _set([
      for (final p in state)
        if (p.id == projectId)
          p.copyWith(
            tasks: [
              for (final e in p.tasks)
                if (e.id != t.id) e,
              t,
            ],
          )
        else
          p,
    ]);
  }

  void deleteTask(String projectId, String taskId) => _set([
    for (final p in state)
      if (p.id == projectId)
        p.copyWith(tasks: p.tasks.where((t) => t.id != taskId).toList())
      else
        p,
  ]);

  void toggleDone(String projectId, String taskId) => _set([
    for (final p in state)
      if (p.id == projectId)
        p.copyWith(
          tasks: [
            for (final t in p.tasks)
              t.id == taskId ? t.copyWith(done: !t.done) : t,
          ],
        )
      else
        p,
  ]);
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final name = ref
        .watch(sharedPreferencesProvider)
        .getString(AppConstants.themeKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == name,
      orElse: () => ThemeMode.system,
    );
  }

  void set(ThemeMode mode) {
    state = mode;
    ref
        .read(sharedPreferencesProvider)
        .setString(AppConstants.themeKey, mode.name);
  }
}
