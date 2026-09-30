import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/planner_controller.dart';
import '../domain/models.dart';
import 'task_editor.dart';
import 'task_format.dart';

/// Actions for one task: complete, edit, send back to the inbox, delete.
Future<void> showTaskSheet(
  BuildContext context,
  WidgetRef ref, {
  required Project project,
  required PlanTask task,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => _TaskSheet(
      project: project,
      task: task,
      onEdit: () async {
        Navigator.pop(ctx);
        final r = await showTaskEditor(
          context,
          projects: ref.read(plannerProvider),
          projectId: project.id,
          task: task,
        );
        if (r != null) {
          ref.read(plannerProvider.notifier).upsertTask(r.projectId, r.task);
        }
      },
    ),
  );
}

class _TaskSheet extends ConsumerWidget {
  const _TaskSheet({
    required this.project,
    required this.task,
    required this.onEdit,
  });
  final Project project;
  final PlanTask task;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(plannerProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 6, backgroundColor: project.color),
                const SizedBox(width: 8),
                Text(
                  project.name,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (task.autoPlaced) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.auto_awesome, size: 14),
                  const Text(' planned for you'),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(taskWhen(task)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  icon: Icon(task.done ? Icons.undo : Icons.check),
                  label: Text(task.done ? 'Mark as open' : 'Mark done'),
                  onPressed: () {
                    notifier.toggleDone(project.id, task.id);
                    Navigator.pop(context);
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  onPressed: onEdit,
                ),
                if (task.autoPlaced)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.inbox_outlined),
                    label: const Text('Unplace'),
                    onPressed: () {
                      notifier.unschedule(project.id, task.id);
                      Navigator.pop(context);
                    },
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  onPressed: () {
                    notifier.deleteTask(project.id, task.id);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
