import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../planner/application/planner_controller.dart';
import '../../planner/domain/models.dart';
import '../../planner/presentation/auto_plan_action.dart';
import '../../planner/presentation/task_editor.dart';
import '../../planner/presentation/task_format.dart';
import '../../planner/presentation/task_sheet.dart';

/// The inbox: tasks waiting for a slot, and what the planner has scheduled.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final n = ref.read(plannerProvider.notifier);
    n.ensureDefaultProject();
    final r = await showTaskEditor(
      context,
      projects: ref.read(plannerProvider),
    );
    if (r != null) n.upsertTask(r.projectId, r.task);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(plannerProvider);
    final now = DateTime.now();
    final all = [
      for (final p in projects)
        for (final t in p.tasks) (p: p, t: t),
    ];
    final toPlace =
        all.where((e) => !e.t.fixed && !e.t.done && !e.t.scheduled).toList()
          ..sort((a, b) {
            final da = a.t.deadline, db = b.t.deadline;
            if (da != null && db != null) return da.compareTo(db);
            if (da != null) return -1;
            if (db != null) return 1;
            return b.t.priority.compareTo(a.t.priority);
          });
    final planned =
        all
            .where(
              (e) =>
                  e.t.autoPlaced &&
                  !e.t.done &&
                  e.t.scheduled &&
                  e.t.end!.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.t.start!.compareTo(b.t.start!));

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Task'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    toPlace.isEmpty
                        ? 'Everything has a slot'
                        : '${toPlace.length} task${toPlace.length == 1 ? '' : 's'} waiting for a slot',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Auto-plan fits them into your free time, around your '
                    'fixed events, and adapts to the hours you really work.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => runAutoPlan(context, ref),
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(planned.isEmpty ? 'Auto-plan' : 'Re-plan all'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (toPlace.isNotEmpty) ...[
            Text('To place', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final e in toPlace) _Row(project: e.p, task: e.t),
          ],
          if (planned.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Planned for you',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final e in planned) _Row(project: e.p, task: e.t),
          ],
          if (toPlace.isEmpty && planned.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: Text('Add a task to get started.')),
            ),
        ],
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.project, required this.task});
  final Project project;
  final PlanTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final overdue =
        task.deadline != null &&
        task.deadline!.isBefore(DateTime.now()) &&
        !task.scheduled;
    return Card(
      child: ListTile(
        onTap: () => showTaskSheet(context, ref, project: project, task: task),
        leading: CircleAvatar(radius: 6, backgroundColor: project.color),
        title: Text(task.title),
        subtitle: Text(
          taskWhen(task),
          style: overdue ? TextStyle(color: scheme.error) : null,
        ),
        trailing: task.priority == 2
            ? Icon(Icons.priority_high, color: scheme.error)
            : null,
      ),
    );
  }
}
