import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../data/planner_repository.dart';
import '../domain/auto_planner.dart';
import '../domain/habit_profile.dart';
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

final habitProvider = NotifierProvider<HabitController, HabitProfile>(
  HabitController.new,
);

String newId() => DateTime.now().microsecondsSinceEpoch.toRadixString(36);

/// Outcome of an auto-plan run, including what is needed to undo it.
class PlanSummary {
  const PlanSummary(this.placed, this.unplaced, this.previous);
  final int placed;
  final List<Unplaced> unplaced;
  final List<Project> previous;
}

class HabitController extends Notifier<HabitProfile> {
  @override
  HabitProfile build() => ref.watch(plannerRepositoryProvider).loadHabits();

  void update(HabitProfile next) {
    state = next;
    ref.read(plannerRepositoryProvider).saveHabits(next);
  }
}

class PlannerController extends Notifier<List<Project>> {
  @override
  List<Project> build() => ref.watch(plannerRepositoryProvider).load();

  void _set(List<Project> next) {
    state = next;
    ref.read(plannerRepositoryProvider).save(next);
  }

  /// Used when a task is created before any project exists.
  String ensureDefaultProject() {
    if (state.isNotEmpty) return state.first.id;
    final p = Project(
      id: newId(),
      name: 'Inbox',
      colorValue: projectPalette[0],
    );
    _set([p]);
    return p.id;
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
    _learnFromMove(projectId, t);
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

  /// If the user changed the time of a task the planner had placed, that is
  /// feedback: the planner guessed wrong about that hour.
  void _learnFromMove(String projectId, PlanTask updated) {
    final old = [
      for (final p in state)
        if (p.id == projectId) ...p.tasks.where((e) => e.id == updated.id),
    ].firstOrNull;
    if (old == null ||
        !old.autoPlaced ||
        !old.scheduled ||
        !updated.scheduled) {
      return;
    }
    if (old.start == updated.start) return;
    final habits = ref.read(habitProvider.notifier);
    habits.update(
      ref.read(habitProvider).recordMove(old.start!.hour, updated.start!.hour),
    );
  }

  void deleteTask(String projectId, String taskId) => _set([
    for (final p in state)
      if (p.id == projectId)
        p.copyWith(tasks: p.tasks.where((t) => t.id != taskId).toList())
      else
        p,
  ]);

  void toggleDone(String projectId, String taskId) {
    final now = DateTime.now();
    _set([
      for (final p in state)
        if (p.id == projectId)
          p.copyWith(
            tasks: [
              for (final t in p.tasks)
                if (t.id != taskId)
                  t
                else ...[
                  () {
                    // Finishing a task inside its planned slot shows you work
                    // well at that hour.
                    if (!t.done &&
                        t.scheduled &&
                        t.autoPlaced &&
                        now.isAfter(
                          t.start!.subtract(const Duration(minutes: 30)),
                        ) &&
                        now.isBefore(t.end!.add(const Duration(hours: 1)))) {
                      ref
                          .read(habitProvider.notifier)
                          .update(
                            ref
                                .read(habitProvider)
                                .recordCompletion(t.start!.hour),
                          );
                    }
                    return t.copyWith(done: !t.done);
                  }(),
                ],
            ],
          )
        else
          p,
    ]);
  }

  /// Sends an auto-placed task back to the inbox.
  void unschedule(String projectId, String taskId) => _set([
    for (final p in state)
      if (p.id == projectId)
        p.copyWith(
          tasks: [
            for (final t in p.tasks) t.id == taskId ? t.unscheduled() : t,
          ],
        )
      else
        p,
  ]);

  void restore(List<Project> previous) => _set(previous);

  /// Finds slots for every flexible task. With [replan], tasks the planner
  /// placed earlier (and that have not started) are re-placed too, so what it
  /// learned since then takes effect.
  PlanSummary autoPlan({bool replan = true}) {
    final now = DateTime.now();
    final previous = state;

    var projects = state;
    if (replan) {
      projects = [
        for (final p in projects)
          p.copyWith(
            tasks: [
              for (final t in p.tasks)
                if (t.autoPlaced &&
                    !t.done &&
                    t.scheduled &&
                    t.start!.isAfter(now))
                  t.unscheduled()
                else
                  t,
            ],
          ),
      ];
    }

    final flexible = [
      for (final p in projects)
        for (final t in p.tasks)
          if (!t.fixed && !t.done && !t.scheduled) (projectId: p.id, task: t),
    ];
    final busy = <Span>[
      for (final p in projects)
        for (final t in p.tasks)
          if (t.scheduled && !t.done && t.end!.isAfter(now))
            (start: t.start!, end: t.end!),
    ];

    final result = const AutoPlanner().plan(
      flexible: flexible,
      busy: busy,
      now: now,
      profile: ref.read(habitProvider),
    );
    final byTask = {for (final pl in result.placed) pl.taskId: pl};

    _set([
      for (final p in projects)
        p.copyWith(
          tasks: [
            for (final t in p.tasks)
              if (byTask[t.id] case final pl?)
                t.copyWith(start: pl.start, end: pl.end, autoPlaced: true)
              else
                t,
          ],
        ),
    ]);
    return PlanSummary(result.placed.length, result.unplaced, previous);
  }
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
