import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../planner/application/planner_controller.dart';
import '../../planner/domain/auto_planner.dart';
import '../../planner/presentation/auto_plan_action.dart';
import '../../planner/presentation/task_editor.dart';
import '../../planner/presentation/task_format.dart';
import '../../planner/presentation/task_sheet.dart';
import 'week_layout.dart';
import 'week_painter.dart';

/// The time map: several days side by side showing commitments, free time and
/// wasted slivers, plus one-tap auto-planning.
class WeekScreen extends ConsumerStatefulWidget {
  const WeekScreen({super.key});

  @override
  ConsumerState<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends ConsumerState<WeekScreen> {
  static const _hourHeight = 56.0;
  DateTime _anchor = DateTime.now();
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    final start = ref.read(habitProvider).workStartHour;
    _scroll = ScrollController(
      initialScrollOffset:
          ((start - 1 - kFirstHour).clamp(0, 12)) * _hourHeight,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<DateTime> _days(int count) {
    var first = DateTime(_anchor.year, _anchor.month, _anchor.day);
    if (count == 7) first = first.subtract(Duration(days: first.weekday - 1));
    return [
      for (var i = 0; i < count; i++)
        DateTime(first.year, first.month, first.day + i),
    ];
  }

  void _shift(int days) => setState(
    () => _anchor = DateTime(_anchor.year, _anchor.month, _anchor.day + days),
  );

  Future<void> _newFixed(DateTime at) async {
    final notifier = ref.read(plannerProvider.notifier);
    notifier.ensureDefaultProject();
    final r = await showTaskEditor(
      context,
      projects: ref.read(plannerProvider),
      start: at,
      duration: const Duration(hours: 1),
      fixed: true,
    );
    if (r != null) notifier.upsertTask(r.projectId, r.task);
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(plannerProvider);
    final profile = ref.watch(habitProvider);
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final toPlace = projects
        .expand((p) => p.tasks)
        .where((t) => !t.fixed && !t.done && !t.scheduled)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time map'),
        actions: [
          IconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.today),
            onPressed: () => setState(() => _anchor = DateTime.now()),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => runAutoPlan(context, ref),
        icon: const Icon(Icons.auto_awesome),
        label: Text(toPlace > 0 ? 'Auto-plan ($toPlace)' : 'Auto-plan'),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final count = c.maxWidth < 600 ? 3 : 7;
          final days = _days(count);
          final from = days.first;
          final to = DateTime(
            days.last.year,
            days.last.month,
            days.last.day + 1,
          );
          final busy = busySpans(projects);
          final windows = workingWindows(
            profile,
            from.isBefore(now) ? now : from,
            to,
          );
          final gaps = freeGaps(windows, busy);
          final wasted = [
            for (final g in gaps)
              if (isWastedGap(g, profile)) g,
          ];
          final stats = timeStats(
            busy,
            profile,
            from.isBefore(now) ? now : from,
            to,
          );
          final layout = WeekLayout(
            days: days,
            width: c.maxWidth,
            hourHeight: _hourHeight,
            projects: projects,
          );

          return Column(
            children: [
              _NavBar(
                label: count == 7
                    ? 'Week of ${DateFormat('d MMM').format(days.first)}'
                    : '${DateFormat('d MMM').format(days.first)} – ${DateFormat('d MMM').format(days.last)}',
                onPrev: () => _shift(-count),
                onNext: () => _shift(count),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _Chip(
                      Icons.check_circle_outline,
                      Colors.green,
                      'Free ${formatMinutes(stats.usableMinutes)}',
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      Icons.hourglass_bottom,
                      scheme.tertiary,
                      'Lost ${formatMinutes(stats.wastedMinutes)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // day headers
              Row(
                children: [
                  const SizedBox(width: kTimeColWidth),
                  for (final d in days)
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            DateFormat('EEE').format(d),
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: DateUtils2.sameDay(d, now)
                                ? scheme.primary
                                : Colors.transparent,
                            child: Text(
                              '${d.day}',
                              style: TextStyle(
                                fontSize: 13,
                                color: DateUtils2.sameDay(d, now)
                                    ? scheme.onPrimary
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const Divider(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.only(bottom: 88),
                  child: GestureDetector(
                    onTapUp: (d) {
                      final bar = layout.barAt(d.localPosition);
                      if (bar != null) {
                        showTaskSheet(
                          context,
                          ref,
                          project: bar.project,
                          task: bar.task,
                        );
                        return;
                      }
                      final col = layout.columnAt(d.localPosition.dx);
                      if (col >= 0) {
                        _newFixed(layout.timeAt(col, d.localPosition.dy));
                      }
                    },
                    child: CustomPaint(
                      size: Size(c.maxWidth, layout.height),
                      painter: WeekPainter(
                        layout: layout,
                        profile: profile,
                        wasted: wasted,
                        now: now,
                        scheme: scheme,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });
  final String label;
  final VoidCallback onPrev, onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
      Expanded(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
    ],
  );
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.color, this.text);
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16, color: color),
    label: Text(text, style: const TextStyle(fontSize: 12)),
    visualDensity: VisualDensity.compact,
  );
}
