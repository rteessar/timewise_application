import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/planner_controller.dart';
import '../domain/models.dart';
import 'task_format.dart';

class TaskEdit {
  const TaskEdit(this.projectId, this.task);
  final String projectId;
  final PlanTask task;
}

final _fmt = DateFormat('EEE d MMM, HH:mm');
const _estimates = [15, 30, 45, 60, 90, 120, 180, 240];

/// Bottom sheet to create or edit a task. Returns null if dismissed.
///
/// A task is either *flexible* (estimate + optional deadline + priority; the
/// auto-planner finds its slot) or *fixed* (you pick the exact time).
Future<TaskEdit?> showTaskEditor(
  BuildContext context, {
  required List<Project> projects,
  String? projectId,
  PlanTask? task,
  DateTime? start,
  Duration? duration,
  bool fixed = false,
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
      startFixed: fixed,
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
    this.startFixed = false,
  });
  final List<Project> projects;
  final String? projectId;
  final PlanTask? task;
  final DateTime? start;
  final Duration? duration;
  final bool startFixed;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late String _projectId = widget.projectId ?? widget.projects.first.id;
  late bool _fixed;
  late int _estimate;
  late int _priority;
  DateTime? _deadline;
  late DateTime _start;
  late DateTime _end;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    final now = DateTime.now();
    _fixed = t?.fixed ?? widget.startFixed;
    _estimate = t?.estimateMinutes ?? widget.duration?.inMinutes ?? 60;
    _priority = t?.priority ?? 1;
    _deadline = t?.deadline;
    _start =
        t?.start ??
        widget.start ??
        DateTime(now.year, now.month, now.day, now.hour + 1);
    _end = t?.end ?? _start.add(Duration(minutes: _estimate));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
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

  bool get _valid =>
      _title.text.trim().isNotEmpty && (!_fixed || _end.isAfter(_start));

  PlanTask _build() {
    final old = widget.task;
    final title = _title.text.trim();
    if (_fixed) {
      return PlanTask(
        id: old?.id ?? newId(),
        title: title,
        start: _start,
        end: _end,
        estimateMinutes: _end.difference(_start).inMinutes,
        priority: _priority,
        fixed: true,
        done: old?.done ?? false,
      );
    }
    // Flexible: keep the planner's slot if the task was already placed.
    final keepSlot = old != null && old.autoPlaced && old.scheduled;
    return PlanTask(
      id: old?.id ?? newId(),
      title: title,
      start: keepSlot ? old.start : null,
      end: keepSlot ? old.start!.add(Duration(minutes: _estimate)) : null,
      estimateMinutes: _estimate,
      deadline: _deadline,
      priority: _priority,
      autoPlaced: keepSlot,
      done: old?.done ?? false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.task != null;
    final scheme = Theme.of(context).colorScheme;
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
                labelText: 'What needs doing?',
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
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.auto_awesome),
                  label: Text('Find me a slot'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.push_pin_outlined),
                  label: Text('Fixed time'),
                ),
              ],
              selected: {_fixed},
              onSelectionChanged: (s) => setState(() => _fixed = s.first),
            ),
            const SizedBox(height: 16),
            if (_fixed) ...[
              _DateTile(
                label: 'Starts',
                value: _start,
                onTap: () async {
                  final v = await _pickDateTime(_start);
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
                  final v = await _pickDateTime(_end);
                  if (v != null) setState(() => _end = v);
                },
              ),
            ] else ...[
              Text('How long?', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in _estimates)
                    ChoiceChip(
                      label: Text(formatMinutes(m)),
                      selected: _estimate == m,
                      onSelected: (_) => setState(() => _estimate = m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Deadline'),
                subtitle: Text(
                  _deadline == null ? 'None' : _fmt.format(_deadline!),
                ),
                trailing: _deadline == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _deadline = null),
                      ),
                onTap: () async {
                  final v = await _pickDateTime(
                    _deadline ?? DateTime.now().add(const Duration(days: 3)),
                  );
                  if (v != null) setState(() => _deadline = v);
                },
              ),
              const SizedBox(height: 4),
              SegmentedButton<int>(
                segments: [
                  for (var i = 0; i < 3; i++)
                    ButtonSegment(value: i, label: Text(priorityLabels[i])),
                ],
                selected: {_priority},
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                'TimeWise will place this in free time that suits you.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _valid
                  ? () => Navigator.pop(context, TaskEdit(_projectId, _build()))
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
