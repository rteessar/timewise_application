import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/planner_controller.dart';
import 'task_format.dart';

/// Runs the planner and tells the user what happened, with undo.
Future<void> runAutoPlan(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(plannerProvider.notifier);
  final hasFlexible = ref
      .read(plannerProvider)
      .expand((p) => p.tasks)
      .any((t) => !t.fixed && !t.done);
  final messenger = ScaffoldMessenger.of(context);
  if (!hasFlexible) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Add a task with "Find me a slot" and I will place it.'),
      ),
    );
    return;
  }

  final summary = notifier.autoPlan();
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        summary.unplaced.isEmpty
            ? 'Placed ${summary.placed} task${summary.placed == 1 ? '' : 's'} in your free time'
            : 'Placed ${summary.placed} · ${summary.unplaced.length} did not fit',
      ),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => notifier.restore(summary.previous),
      ),
    ),
  );

  if (summary.unplaced.isNotEmpty && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Couldn't fit these"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final u in summary.unplaced)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${u.task.title} (${formatMinutes(u.task.estimateMinutes)})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(u.reason),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              notifier.restore(summary.previous);
              Navigator.pop(ctx);
            },
            child: const Text('Undo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
