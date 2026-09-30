import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../planner/application/planner_controller.dart';
import '../../planner/domain/models.dart';
import '../../planner/presentation/task_editor.dart';
import 'timeline_layout.dart';
import 'timeline_painter.dart';

/// The "map": an unbounded pan/zoom canvas where x is time and each project
/// is a lane. Pinch or scroll-wheel to zoom from years down to hours.
class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  double _ppd = AppConstants.defaultPixelsPerDay;
  double? _leftDay;
  double _scrollY = 0;
  Size _size = Size.zero;
  String? _selected;

  // gesture baselines
  double _startPpd = 1;
  double _focalDay = 0;
  double _startScrollY = 0;
  double _startFocalY = 0;

  late final DateTime _now = DateTime.now();

  double get _centerDay => (_leftDay ?? 0) + _size.width / 2 / _ppd;

  void _goToNow() => setState(() {
    // Put "now" at one third of the screen so the near future is visible.
    _leftDay = dayOf(DateTime.now()) - _size.width / 3 / _ppd;
  });

  void _zoomTo(double ppd, {double? anchorX}) {
    final ax = anchorX ?? _size.width / 2;
    final day = (_leftDay ?? 0) + ax / _ppd;
    final next = ppd.clamp(
      AppConstants.minPixelsPerDay,
      AppConstants.maxPixelsPerDay,
    );
    setState(() {
      _ppd = next;
      _leftDay = day - ax / next;
    });
  }

  void _clampScroll(double contentHeight) {
    final max = math.max(0.0, contentHeight - _size.height + 80);
    _scrollY = _scrollY.clamp(0.0, max);
  }

  Future<void> _addTask(
    List<Project> projects, {
    String? projectId,
    DateTime? at,
  }) async {
    if (projects.isEmpty) return;
    final hourly = _ppd >= 200;
    final r = await showTaskEditor(
      context,
      projects: projects,
      projectId: projectId,
      start: at,
      duration: hourly ? const Duration(hours: 2) : const Duration(days: 1),
    );
    if (r != null) {
      ref.read(plannerProvider.notifier).upsertTask(r.projectId, r.task);
    }
  }

  void _openTask(BarRect bar, List<Project> projects) {
    setState(() => _selected = bar.task.id);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => _TaskSheet(
        project: bar.project,
        task: bar.task,
        onEdit: () async {
          Navigator.pop(ctx);
          final r = await showTaskEditor(
            context,
            projects: projects,
            projectId: bar.project.id,
            task: bar.task,
          );
          if (r != null) {
            ref.read(plannerProvider.notifier).upsertTask(r.projectId, r.task);
          }
        },
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selected = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(plannerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: [
          IconButton(
            tooltip: 'Jump to today',
            icon: const Icon(Icons.my_location),
            onPressed: _goToNow,
          ),
        ],
      ),
      floatingActionButton: projects.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addTask(projects),
              icon: const Icon(Icons.add),
              label: const Text('Task'),
            ),
      body: projects.isEmpty
          ? _Empty(onCreate: () => context.push('/project/new'))
          : LayoutBuilder(
              builder: (context, c) {
                _size = Size(c.maxWidth, c.maxHeight);
                _leftDay ??= dayOf(DateTime.now()) - _size.width / 3 / _ppd;
                final layout = TimelineLayout.build(
                  projects,
                  leftDay: _leftDay!,
                  pixelsPerDay: _ppd,
                );
                _clampScroll(layout.contentHeight);

                return Stack(
                  children: [
                    Listener(
                      onPointerSignal: (e) {
                        if (e is PointerScrollEvent) {
                          _zoomTo(
                            _ppd * math.exp(-e.scrollDelta.dy / 300),
                            anchorX: e.localPosition.dx,
                          );
                        }
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: (d) {
                          _startPpd = _ppd;
                          _focalDay = _leftDay! + d.localFocalPoint.dx / _ppd;
                          _startScrollY = _scrollY;
                          _startFocalY = d.localFocalPoint.dy;
                        },
                        onScaleUpdate: (d) => setState(() {
                          _ppd = (_startPpd * d.scale).clamp(
                            AppConstants.minPixelsPerDay,
                            AppConstants.maxPixelsPerDay,
                          );
                          _leftDay = _focalDay - d.localFocalPoint.dx / _ppd;
                          _scrollY =
                              _startScrollY -
                              (d.localFocalPoint.dy - _startFocalY);
                          _clampScroll(layout.contentHeight);
                        }),
                        onTapUp: (d) {
                          final p = d.localPosition + Offset(0, _scrollY);
                          if (d.localPosition.dy < kHeaderHeight) return;
                          final bar = layout.barAt(p);
                          if (bar != null) _openTask(bar, projects);
                        },
                        onLongPressStart: (d) {
                          if (d.localPosition.dy < kHeaderHeight) return;
                          final lane = layout.laneAt(
                            d.localPosition.dy + _scrollY,
                          );
                          if (lane == null) return;
                          var at = timeOfDay(
                            _leftDay! + d.localPosition.dx / _ppd,
                          );
                          at = _ppd >= 200
                              ? DateTime(at.year, at.month, at.day, at.hour)
                              : DateTime(at.year, at.month, at.day, 9);
                          _addTask(
                            projects,
                            projectId: lane.project.id,
                            at: at,
                          );
                        },
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: TimelinePainter(
                            layout: layout,
                            leftDay: _leftDay!,
                            pixelsPerDay: _ppd,
                            scrollY: _scrollY,
                            now: _now,
                            scheme: scheme,
                            selectedTaskId: _selected,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _ZoomBar(
                        ppd: _ppd,
                        onZoom: _zoomTo,
                        centerDay: _centerDay,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _ZoomBar extends StatelessWidget {
  const _ZoomBar({
    required this.ppd,
    required this.onZoom,
    required this.centerDay,
  });
  final double ppd;
  final void Function(double ppd, {double? anchorX}) onZoom;
  final double centerDay;

  static const _presets = <(String, double)>[
    ('Hours', 960),
    ('Days', 90),
    ('Weeks', 16),
    ('Months', 4),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 2,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Zoom out',
              icon: const Icon(Icons.remove),
              onPressed: () => onZoom(ppd / 1.6),
            ),
            PopupMenuButton<double>(
              tooltip: 'Zoom level',
              onSelected: (v) => onZoom(v),
              itemBuilder: (_) => [
                for (final (label, v) in _presets)
                  PopupMenuItem(value: v, child: Text(label)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  _levelName(ppd),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Zoom in',
              icon: const Icon(Icons.add),
              onPressed: () => onZoom(ppd * 1.6),
            ),
          ],
        ),
      ),
    );
  }

  static String _levelName(double ppd) {
    if (ppd >= 200) return 'Hours';
    if (ppd >= 24) return 'Days';
    if (ppd >= 6) return 'Weeks';
    return 'Months';
  }
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
    final fmt = DateFormat('EEE d MMM, HH:mm');
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
              ],
            ),
            const SizedBox(height: 8),
            Text(task.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('${fmt.format(task.start)}  →  ${fmt.format(task.end)}'),
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

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.map_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Your map is empty',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a project to get a lane on the timeline, then add tasks and zoom around your plan.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create project'),
          ),
        ],
      ),
    ),
  );
}
