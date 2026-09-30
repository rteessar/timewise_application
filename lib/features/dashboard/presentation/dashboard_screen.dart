import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../planner/application/planner_controller.dart';
import '../../planner/domain/auto_planner.dart';
import '../../planner/domain/models.dart';
import '../../planner/presentation/auto_plan_action.dart';
import '../../planner/presentation/task_format.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(plannerProvider);
    final profile = ref.watch(habitProvider);
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final today = <(Project, PlanTask)>[
      for (final p in projects)
        for (final t in p.tasks)
          if (t.overlaps(dayStart, dayEnd)) (p, t),
    ]..sort((a, b) => a.$2.start!.compareTo(b.$2.start!));

    final overdue = <(Project, PlanTask)>[
      for (final p in projects)
        for (final t in p.tasks)
          if (!t.done &&
              ((t.scheduled && t.end!.isBefore(now)) ||
                  (!t.scheduled &&
                      t.deadline != null &&
                      t.deadline!.isBefore(now))))
            (p, t),
    ];
    final toPlace = projects
        .expand((p) => p.tasks)
        .where((t) => !t.fixed && !t.done && !t.scheduled)
        .length;
    final allTasks = projects.expand((p) => p.tasks).toList();
    final doneCount = allTasks.where((t) => t.done).length;
    final stats = timeStats(busySpans(projects), profile, now, dayEnd);

    return Scaffold(
      appBar: AppBar(title: const Text('TimeWise')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/project/new'),
        icon: const Icon(Icons.add),
        label: const Text('Project'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Text(
            DateFormat('EEEE, d MMMM').format(now),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                'Free today',
                formatMinutes(stats.usableMinutes),
                Icons.spa_outlined,
              ),
              _Stat(
                'Lost to gaps',
                formatMinutes(stats.wastedMinutes),
                Icons.hourglass_bottom,
                alert: stats.wastedMinutes >= 60,
              ),
              _Stat(
                'Done',
                '$doneCount/${allTasks.length}',
                Icons.check_circle_outline,
              ),
            ],
          ),
          if (toPlace > 0) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.auto_awesome),
                title: Text(
                  '$toPlace task${toPlace == 1 ? '' : 's'} need a slot',
                ),
                subtitle: const Text(
                  'Let TimeWise fit them into your free time',
                ),
                trailing: FilledButton(
                  onPressed: () => runAutoPlan(context, ref),
                  child: const Text('Plan'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _Section('Today'),
          if (today.isEmpty)
            const _Hint('Nothing scheduled today.')
          else
            for (final (p, t) in today) _TaskRow(project: p, task: t),
          if (overdue.isNotEmpty) ...[
            const SizedBox(height: 16),
            _Section('Overdue'),
            for (final (p, t) in overdue) _TaskRow(project: p, task: t),
          ],
          const SizedBox(height: 16),
          _Section('Projects'),
          if (projects.isEmpty)
            const _Hint('No projects yet. Tap "Project" to create one.')
          else
            for (final p in projects) _ProjectCard(project: p),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon, {this.alert = false});
  final String label, value;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: alert ? scheme.error : scheme.primary),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  const _TaskRow({required this.project, required this.task});
  final Project project;
  final PlanTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    child: ListTile(
      leading: Checkbox(
        value: task.done,
        activeColor: project.color,
        onChanged: (_) =>
            ref.read(plannerProvider.notifier).toggleDone(project.id, task.id),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: task.done ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text('${project.name} · ${taskWhen(task)}'),
    ),
  );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: () => context.push('/project/${project.id}'),
      leading: CircleAvatar(backgroundColor: project.color, radius: 10),
      title: Text(project.name),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: LinearProgressIndicator(
          value: project.progress,
          color: project.color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      trailing: Text('${project.tasks.length} tasks'),
    ),
  );
}
