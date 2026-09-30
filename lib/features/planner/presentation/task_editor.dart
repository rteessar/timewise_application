import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/planner_controller.dart';
import '../domain/models.dart';

class TaskEdit {
  const TaskEdit(this.projectId, this.task);
  final String projectId;
  final PlanTask task;
}

final _fmt = DateFormat('EEE d MMM, HH:mm');

/// Bottom sheet to create or edit a task. Returns null if dismissed.
/// When [projects] has several entries the user can pick the lane.
Future<TaskEdit?> showTaskEditor(
  BuildContext context, {
  required List<Project> projects,
  String? projectId,
  PlanTask? task,
  DateTime? start,
  Duration? duration,
}) {
  return showModalBottomSheet<TaskEdit>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TaskEditor(
      projects: projects,
      projectId: projectId,
      task: task,
      start: start,
      duration: duration,
    ),
  );
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({
    required this.projects,
    this.projectId,
    this.task,
    this.start,
    this.duration,
  });
  final List<Project> projects;
  final String? projectId;
  final PlanTask? task;
  final DateTime? start;
  final Duration? duration;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late String _projectId = widget.projectId ?? widget.projects.first.id;
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start =
        widget.task?.start ??
        widget.start ??
        DateTime(now.year, now.month, now.day, now.hour + 1);
    _end =
        widget.task?.end ??
        _start.add(widget.duration ?? const Duration(hours: 2));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) async {
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  bool get _valid => _title.text.trim().isNotEmpty && _end.isAfter(_start);

  @override
  Widget build(BuildContext context) {
    final editing = widget.task != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Edit task' : 'New task',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: !editing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (widget.projectId == null && widget.projects.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _projectId,
                decoration: const InputDecoration(
                  labelText: 'Project',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final p in widget.projects)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _projectId = v!),
              ),
            ],
            const SizedBox(height: 12),
            _DateTile(
              label: 'Starts',
              value: _start,
              onTap: () async {
                final v = await _pick(_start);
                if (v == null) return;
                setState(() {
                  final len = _end.difference(_start);
                  _start = v;
                  if (!_end.isAfter(_start)) _end = _start.add(len);
                });
              },
            ),
            _DateTile(
              label: 'Ends',
              value: _end,
              error: !_end.isAfter(_start),
              onTap: () async {
                final v = await _pick(_end);
                if (v != null) setState(() => _end = v);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _valid
                  ? () => Navigator.pop(
                      context,
                      TaskEdit(
                        _projectId,
                        PlanTask(
                          id: widget.task?.id ?? newId(),
                          title: _title.text.trim(),
                          start: _start,
                          end: _end,
                          done: widget.task?.done ?? false,
                        ),
                      ),
                    )
                  : null,
              child: Text(editing ? 'Save' : 'Add task'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.error = false,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.schedule, color: error ? scheme.error : null),
      title: Text(label),
      subtitle: Text(
        error ? 'Must be after the start' : _fmt.format(value),
        style: error ? TextStyle(color: scheme.error) : null,
      ),
      onTap: onTap,
    );
  }
}
