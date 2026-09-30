import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../planner/application/planner_controller.dart';
import '../../planner/domain/models.dart';
import '../../planner/presentation/task_editor.dart';
import '../../planner/presentation/task_format.dart';

/// Create or edit a project (a lane) together with its tasks.
/// Changes are kept in a local draft and committed on Save.
class ProjectComposerScreen extends ConsumerStatefulWidget {
  const ProjectComposerScreen({super.key, this.projectId});
  final String? projectId;

  @override
  ConsumerState<ProjectComposerScreen> createState() => _State();
}

class _State extends ConsumerState<ProjectComposerScreen> {
  late final TextEditingController _name;
  late int _color;
  late List<PlanTask> _tasks;
  late final String _id;
  late final bool _isNew;

  @override
  void initState() {
    super.initState();
    final existing = widget.projectId == null
        ? null
        : ref
              .read(plannerProvider)
              .where((p) => p.id == widget.projectId)
              .firstOrNull;
    _isNew = existing == null;
    _id = existing?.id ?? newId();
    _name = TextEditingController(text: existing?.name ?? '');
    _color =
        existing?.colorValue ??
        projectPalette[ref.read(plannerProvider).length %
            projectPalette.length];
    _tasks = [...?existing?.tasks];
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Project get _draft => Project(
    id: _id,
    name: _name.text.trim(),
    colorValue: _color,
    tasks: _tasks,
  );

  Future<void> _editTask([PlanTask? task]) async {
    final r = await showTaskEditor(
      context,
      projects: [_draft],
      projectId: _id,
      task: task,
    );
    if (r == null) return;
    setState(() {
      _tasks =
          [
            for (final t in _tasks)
              if (t.id != r.task.id) t,
            r.task,
          ]..sort(
            (a, b) => (a.start ?? DateTime(9999)).compareTo(
              b.start ?? DateTime(9999),
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New project' : 'Edit project'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete project',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete project?'),
                    content: Text(
                      '"${_name.text}" and its ${_tasks.length} tasks will be removed.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  ref.read(plannerProvider.notifier).deleteProject(_id);
                  context.pop();
                }
              },
            ),
          TextButton(
            onPressed: _name.text.trim().isEmpty
                ? null
                : () {
                    ref.read(plannerProvider.notifier).upsertProject(_draft);
                    context.pop();
                  },
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            autofocus: _isNew,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Project name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Text('Colour', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in projectPalette)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(c),
                    child: _color == c
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Tasks', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _editTask(),
                icon: const Icon(Icons.add),
                label: const Text('Add task'),
              ),
            ],
          ),
          if (_tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No tasks yet.'),
            ),
          for (final t in _tasks)
            Card(
              child: ListTile(
                title: Text(t.title),
                subtitle: Text(taskWhen(t)),
                onTap: () => _editTask(t),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(
                    () => _tasks = _tasks.where((e) => e.id != t.id).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
