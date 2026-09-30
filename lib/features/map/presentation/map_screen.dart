import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../planner/application/planner_controller.dart';
import '../../planner/domain/auto_planner.dart';
import '../../planner/presentation/auto_plan_action.dart';
import '../../planner/presentation/task_editor.dart';
import '../../planner/presentation/task_format.dart';
import '../../planner/presentation/task_sheet.dart';
import 'map_layout.dart';
import 'map_painter.dart';
import 'map_viewport.dart';

/// The map of your time: drag in any direction (days sideways, hours up and
/// down), pinch or Ctrl+scroll to zoom, fling to glide. Free time is green,
/// lost time is hatched, commitments are blocks.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  MapViewport? _vp;
  Size _size = Size.zero;

  // gesture state
  MapViewport? _gestureStart;
  Offset _startFocal = Offset.zero;
  bool _scaled = false;

  Ticker? _fling;

  @override
  void dispose() {
    _fling?.dispose();
    super.dispose();
  }

  MapViewport _initial(Size size) {
    final now = DateTime.now();
    final habits = ref.read(habitProvider);
    final days = size.width < 600 ? 3.3 : 7.0;
    final zoom =
        ((size.width - MapViewport.gutterWidth) /
                (days * MapViewport.baseColumnWidth))
            .clamp(MapViewport.minZoom, MapViewport.maxZoom)
            .toDouble();
    return MapViewport(
      leftDay: dayNumber(now) - 0.15,
      topHour: (habits.workStartHour - 1).toDouble(),
      zoom: zoom,
      size: size,
    ).clamped();
  }

  void _stopFling() {
    _fling?.dispose();
    _fling = null;
  }

  void _startFling(Offset velocity) {
    _stopFling();
    if (velocity.distance < 150) return;
    final sx = FrictionSimulation(0.12, 0, velocity.dx);
    final sy = FrictionSimulation(0.12, 0, velocity.dy);
    var lastX = 0.0, lastY = 0.0;
    _fling = createTicker((elapsed) {
      final t = elapsed.inMicroseconds / 1e6;
      final x = sx.x(t), y = sy.x(t);
      setState(() => _vp = _vp!.panBy(Offset(x - lastX, y - lastY)));
      lastX = x;
      lastY = y;
      if (sx.isDone(t) && sy.isDone(t)) _stopFling();
    })..start();
  }

  void _goToToday() {
    _stopFling();
    final v = _vp!;
    setState(
      () => _vp = v.copyWith(
        leftDay: dayNumber(DateTime.now()) - 0.15,
        topHour: (ref.read(habitProvider).workStartHour - 1).toDouble(),
      ),
    );
  }

  void _zoomBy(double factor) {
    _stopFling();
    final v = _vp!;
    final center = Offset(
      MapViewport.gutterWidth + (v.size.width - MapViewport.gutterWidth) / 2,
      MapViewport.headerHeight + (v.size.height - MapViewport.headerHeight) / 2,
    );
    setState(() => _vp = v.zoomAt(center, factor));
  }

  bool get _ctrlDown =>
      HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed;

  void _onPointerSignal(PointerSignalEvent e) {
    final v = _vp;
    if (v == null) return;
    _stopFling();
    if (e is PointerScaleEvent) {
      // trackpad pinch
      setState(() => _vp = v.zoomAt(e.localPosition, e.scale));
    } else if (e is PointerScrollEvent) {
      if (_ctrlDown) {
        setState(
          () => _vp = v.zoomAt(
            e.localPosition,
            (1 - e.scrollDelta.dy / 300).clamp(0.5, 2.0),
          ),
        );
      } else {
        // wheel / two-finger scroll pans
        setState(() => _vp = v.panBy(-e.scrollDelta));
      }
    }
  }

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

  void _onTap(Offset p, List<MapBar> bars) {
    final v = _vp!;
    if (p.dx < MapViewport.gutterWidth || p.dy < MapViewport.headerHeight) {
      return;
    }
    final bar = barAt(bars, p);
    if (bar != null) {
      showTaskSheet(context, ref, project: bar.project, task: bar.task);
      return;
    }
    final day = dateOfDay(v.dayAtX(p.dx).floor());
    final minutes = ((v.hourAtY(p.dy) * 60) / 30).floor() * 30;
    if (minutes < 0 || minutes >= 24 * 60) return;
    _newFixed(DateTime(day.year, day.month, day.day, 0, minutes));
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
        title: const Text('Map'),
        actions: [
          IconButton(
            tooltip: 'Jump to today',
            icon: const Icon(Icons.my_location),
            onPressed: _vp == null ? null : _goToToday,
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
          final size = Size(c.maxWidth, c.maxHeight);
          if (_vp == null) {
            _vp = _initial(size);
          } else if (size != _size) {
            _vp = MapViewport(
              leftDay: _vp!.leftDay,
              topHour: _vp!.topHour,
              zoom: _vp!.zoom,
              size: size,
            ).clamped();
          }
          _size = size;
          final v = _vp!;

          final bars = layoutBars(projects, v);
          final busy = busySpans(projects);
          final from = dateOfDay(v.firstDay);
          final to = dateOfDay(v.lastDay + 1);
          final windows = workingWindows(
            profile,
            from.isBefore(now) ? now : from,
            to,
          );
          final wasted = [
            for (final g in freeGaps(windows, busy))
              if (isWastedGap(g, profile)) g,
          ];
          final stats = timeStats(
            busy,
            profile,
            from.isBefore(now) ? now : from,
            to,
          );

          return Stack(
            children: [
              Listener(
                onPointerSignal: _onPointerSignal,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onScaleStart: (d) {
                    _stopFling();
                    _gestureStart = _vp;
                    _startFocal = d.localFocalPoint;
                    _scaled = false;
                  },
                  onScaleUpdate: (d) {
                    final start = _gestureStart!;
                    if ((d.scale - 1).abs() > 0.02) _scaled = true;
                    // zoom around the start focal point, then translate by how
                    // far the focal point has travelled since the gesture began
                    var next = start.zoomAt(_startFocal, d.scale);
                    next = next.panBy(d.localFocalPoint - _startFocal);
                    setState(() => _vp = next);
                  },
                  onScaleEnd: (d) {
                    if (!_scaled) _startFling(d.velocity.pixelsPerSecond);
                  },
                  onTapUp: (d) => _onTap(d.localPosition, bars),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: MapPainter(
                      viewport: v,
                      bars: bars,
                      profile: profile,
                      wasted: wasted,
                      now: now,
                      scheme: scheme,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: MapViewport.gutterWidth + 8,
                top: MapViewport.headerHeight + 8,
                child: IgnorePointer(
                  child: Wrap(
                    spacing: 6,
                    children: [
                      _Pill(
                        Icons.check_circle_outline,
                        Colors.green,
                        'Free ${formatMinutes(stats.usableMinutes)}',
                      ),
                      _Pill(
                        Icons.hourglass_bottom,
                        scheme.tertiary,
                        'Lost ${formatMinutes(stats.wastedMinutes)}',
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: MapViewport.gutterWidth + 8,
                bottom: 12,
                child: Material(
                  color: scheme.surfaceContainerHigh,
                  elevation: 2,
                  borderRadius: BorderRadius.circular(24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Zoom out',
                        icon: const Icon(Icons.remove),
                        onPressed: () => _zoomBy(1 / 1.4),
                      ),
                      IconButton(
                        tooltip: 'Zoom in',
                        icon: const Icon(Icons.add),
                        onPressed: () => _zoomBy(1.4),
                      ),
                    ],
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

class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.color, this.text);
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
