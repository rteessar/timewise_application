import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timewise_application/app.dart';
import 'package:timewise_application/features/planner/application/planner_controller.dart';
import 'package:timewise_application/features/planner/domain/auto_planner.dart';
import 'package:timewise_application/features/planner/domain/habit_profile.dart';
import 'package:timewise_application/features/planner/domain/models.dart';
import 'package:timewise_application/features/map/presentation/map_layout.dart';
import 'package:timewise_application/features/map/presentation/map_viewport.dart';
import 'package:timewise_application/features/timeline/presentation/timeline_layout.dart';

Future<ProviderContainer> _boot(
  WidgetTester tester, [
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const TimeWiseApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  plannerTests();
  mapTests();
  test('project JSON round-trips', () {
    final p = Project(
      id: 'a',
      name: 'P',
      colorValue: 0xFF6366F1,
      tasks: [
        PlanTask(
          id: 't',
          title: 'T',
          start: DateTime(2026, 1, 1, 9),
          end: DateTime(2026, 1, 1, 11),
          done: true,
        ),
      ],
    );
    final back = Project.fromJson(p.toJson());
    expect(back.name, 'P');
    expect(back.tasks.single.done, isTrue);
    expect(back.tasks.single.end, DateTime(2026, 1, 1, 11));
  });

  test('overlapping tasks are stacked into separate rows', () {
    final d = DateTime(2026, 1, 1);
    PlanTask t(String id, int h0, int h1) => PlanTask(
      id: id,
      title: id,
      start: d.add(Duration(hours: h0)),
      end: d.add(Duration(hours: h1)),
    );
    final layout = TimelineLayout.build(
      [
        Project(
          id: 'p',
          name: 'P',
          colorValue: 0xFF000000,
          tasks: [t('a', 0, 10), t('b', 5, 15), t('c', 40, 41)],
        ),
      ],
      leftDay: dayOf(d),
      pixelsPerDay: 48,
    );
    final a = layout.bars.firstWhere((b) => b.task.id == 'a').rect;
    final b = layout.bars.firstWhere((b) => b.task.id == 'b').rect;
    final c = layout.bars.firstWhere((b) => b.task.id == 'c').rect;
    expect(a.top, isNot(b.top));
    expect(c.top, a.top);
  });

  testWidgets('add a flexible task, auto-plan it, see it on the map', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = await _boot(tester);

    // Starts on the time map.
    expect(find.text('Map'), findsWidgets);
    expect(find.byTooltip('Zoom in'), findsOneWidget);

    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Task').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Write report');
    await tester.pump();
    await tester.tap(find.text('Add task'));
    await tester.pumpAndSettle();

    var task = container.read(plannerProvider).single.tasks.single;
    expect(task.fixed, isFalse);
    expect(task.scheduled, isFalse);
    expect(find.text('Write report'), findsOneWidget);

    await tester.tap(find.text('Auto-plan').last);
    await tester.pumpAndSettle();

    task = container.read(plannerProvider).single.tasks.single;
    expect(task.scheduled, isTrue);
    expect(task.autoPlaced, isTrue);
    expect(task.start!.isAfter(DateTime.now()), isTrue);
    expect(task.start!.weekday, lessThanOrEqualTo(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('finishing a planned task in its slot teaches the planner', (
    tester,
  ) async {
    final container = await _boot(tester);
    final now = DateTime.now();
    final start = now.subtract(const Duration(minutes: 10));
    container
        .read(plannerProvider.notifier)
        .upsertProject(
          Project(
            id: 'p',
            name: 'Work',
            colorValue: 0xFF6366F1,
            tasks: [
              PlanTask(
                id: 't',
                title: 'Focus',
                start: start,
                end: start.add(const Duration(hours: 1)),
                autoPlaced: true,
              ),
            ],
          ),
        );
    expect(container.read(habitProvider).signals, 0);
    container.read(plannerProvider.notifier).toggleDone('p', 't');
    final h = container.read(habitProvider);
    expect(h.signals, 1);
    expect(h.weightAt(start.hour), greaterThan(1));
  });

  testWidgets('map drags in 2D, zooms and flings without errors', (
    tester,
  ) async {
    final container = await _boot(tester);
    container
        .read(plannerProvider.notifier)
        .upsertProject(
          Project(
            id: 'p',
            name: 'Work',
            colorValue: 0xFF6366F1,
            tasks: [
              PlanTask(
                id: 't',
                title: 'Ship it',
                start: DateTime.now(),
                end: DateTime.now().add(const Duration(hours: 3)),
                fixed: true,
              ),
            ],
          ),
        );
    await tester.pumpAndSettle();
    final map = find.byType(CustomPaint).last;
    await tester.drag(map, const Offset(-300, -120));
    await tester.pump();
    await tester.fling(map, const Offset(400, 200), 2000);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.tap(find.byTooltip('Jump to today'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline tab pans and zooms without errors', (tester) async {
    final container = await _boot(tester);
    container
        .read(plannerProvider.notifier)
        .upsertProject(
          Project(
            id: 'p',
            name: 'Work',
            colorValue: 0xFF6366F1,
            tasks: [
              PlanTask(
                id: 't',
                title: 'Ship it',
                start: DateTime.now(),
                end: DateTime.now().add(const Duration(days: 2)),
                fixed: true,
              ),
            ],
          ),
        );
    await tester.tap(find.text('Timeline').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomPaint).last, const Offset(-200, -40));
    await tester.pump();
    for (final label in ['Zoom in', 'Zoom in', 'Zoom in', 'Zoom out']) {
      await tester.tap(find.byTooltip(label));
      await tester.pump();
    }
    await tester.tap(find.byTooltip('Jump to today'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

// ---------------------------------------------------------------- planner --

void plannerTests() {
  // Monday 2030-01-07 08:00, well in the future and far from DST changes.
  final now = DateTime(2030, 1, 7, 8);
  PlanTask flex(
    String id,
    int minutes, {
    DateTime? deadline,
    int priority = 1,
  }) => PlanTask(
    id: id,
    title: id,
    estimateMinutes: minutes,
    deadline: deadline,
    priority: priority,
  );
  ({String projectId, PlanTask task}) item(PlanTask t) =>
      (projectId: 'p', task: t);

  group('AutoPlanner', () {
    test('places tasks inside working hours and never overlaps', () {
      final profile = HabitProfile();
      final tasks = [for (var i = 0; i < 8; i++) flex('t$i', 90)];
      final r = const AutoPlanner().plan(
        flexible: tasks.map(item).toList(),
        busy: [],
        now: now,
        profile: profile,
      );
      expect(r.unplaced, isEmpty);
      final spans = [...r.placed]..sort((a, b) => a.start.compareTo(b.start));
      for (final p in spans) {
        expect(p.start.hour, greaterThanOrEqualTo(profile.workStartHour));
        final dayEnd = DateTime(
          p.end.year,
          p.end.month,
          p.end.day,
          profile.workEndHour,
        );
        expect(p.end.isAfter(dayEnd), isFalse);
        expect(p.start.weekday, lessThanOrEqualTo(5));
      }
      for (var i = 1; i < spans.length; i++) {
        expect(spans[i].start.isBefore(spans[i - 1].end), isFalse);
      }
    });

    test('routes around fixed commitments', () {
      final meeting = (
        start: DateTime(2030, 1, 7, 9),
        end: DateTime(2030, 1, 7, 12),
      );
      final r = const AutoPlanner().plan(
        flexible: [item(flex('a', 60))],
        busy: [meeting],
        now: now,
        profile: HabitProfile(),
      );
      final p = r.placed.single;
      expect(p.start.isBefore(meeting.end), isFalse);
      expect(
        p.start,
        DateTime(2030, 1, 7, 12, 10),
      ); // right after + 10 min break
    });

    test('does not leave unusable slivers around a task', () {
      final meeting = (
        start: DateTime(2030, 1, 7, 11),
        end: DateTime(2030, 1, 7, 12),
      );
      final r = const AutoPlanner().plan(
        flexible: [item(flex('a', 90))],
        busy: [meeting],
        now: now,
        profile: HabitProfile(),
      );
      // 9:00 leaves a 30 min gap before the meeting; 9:15 would leave 15.
      expect(r.placed.single.start, DateTime(2030, 1, 7, 9));
    });

    test('a task with a near deadline goes before a relaxed one', () {
      final r = const AutoPlanner().plan(
        flexible: [
          item(flex('relaxed', 60)),
          item(flex('urgent', 60, deadline: DateTime(2030, 1, 7, 12))),
        ],
        busy: [],
        now: now,
        profile: HabitProfile(),
      );
      final by = {for (final p in r.placed) p.taskId: p};
      expect(by['urgent']!.start.isBefore(by['relaxed']!.start), isTrue);
      expect(by['urgent']!.end.isAfter(DateTime(2030, 1, 7, 12)), isFalse);
    });

    test('reports tasks that cannot fit and why', () {
      final r = const AutoPlanner().plan(
        flexible: [
          item(flex('huge', 12 * 60)),
          item(flex('late', 60, deadline: DateTime(2030, 1, 7, 8, 30))),
        ],
        busy: [],
        now: now,
        profile: HabitProfile(),
      );
      expect(r.placed, isEmpty);
      expect(r.unplaced.map((u) => u.task.id), containsAll(['huge', 'late']));
      expect(
        r.unplaced.firstWhere((u) => u.task.id == 'huge').reason,
        contains('split'),
      );
    });

    test('learned preference for afternoons moves placements there', () {
      var profile = HabitProfile();
      for (var i = 0; i < 12; i++) {
        profile = profile.recordCompletion(15);
      }
      final base = const AutoPlanner().plan(
        flexible: [item(flex('a', 60))],
        busy: [],
        now: now,
        profile: HabitProfile(),
      );
      final learned = const AutoPlanner().plan(
        flexible: [item(flex('a', 60))],
        busy: [],
        now: now,
        profile: profile,
      );
      expect(base.placed.single.start.hour, 9);
      expect(learned.placed.single.start.hour, 15);
    });

    test('skips weekends', () {
      final friday = DateTime(2030, 1, 11, 17, 30);
      final r = const AutoPlanner().plan(
        flexible: [item(flex('a', 60))],
        busy: [],
        now: friday,
        profile: HabitProfile(),
      );
      expect(r.placed.single.start, DateTime(2030, 1, 14, 9));
    });
  });

  group('HabitProfile', () {
    test('moves shift weight away from the old hour, clamped', () {
      var p = HabitProfile();
      for (var i = 0; i < 50; i++) {
        p = p.recordMove(9, 16);
      }
      expect(p.weightAt(9), HabitProfile.minWeight);
      expect(p.weightAt(16), HabitProfile.maxWeight);
      expect(p.signals, 50);
    });

    test('JSON round-trips', () {
      final p = HabitProfile(
        workStartHour: 7,
        workDays: {1, 3},
      ).recordCompletion(10);
      final back = HabitProfile.fromJson(p.toJson());
      expect(back.workStartHour, 7);
      expect(back.workDays, {1, 3});
      expect(back.weightAt(10), p.weightAt(10));
    });
  });

  test('timeStats separates usable time from unusable slivers', () {
    final profile = HabitProfile(workStartHour: 9, workEndHour: 12);
    final busy = [
      (start: DateTime(2030, 1, 7, 9, 20), end: DateTime(2030, 1, 7, 11, 40)),
    ];
    final s = timeStats(
      busy,
      profile,
      DateTime(2030, 1, 7),
      DateTime(2030, 1, 8),
    );
    expect(s.wastedMinutes, 20 + 20); // 9:00-9:20 and 11:40-12:00
    expect(s.usableMinutes, 0);
  });

  test('v1 stored tasks load as fixed tasks', () {
    final t = PlanTask.fromJson({
      'id': 'x',
      'title': 'old',
      'start': '2030-01-07T09:00:00.000',
      'end': '2030-01-07T10:30:00.000',
    });
    expect(t.fixed, isTrue);
    expect(t.estimateMinutes, 90);
  });
}

// -------------------------------------------------------------------- map --

void mapTests() {
  const size = Size(400, 800);
  MapViewport vp({double leftDay = 20000, double top = 6, double zoom = 1}) =>
      MapViewport(leftDay: leftDay, topHour: top, zoom: zoom, size: size);

  group('MapViewport', () {
    test('x/day and y/hour conversions are inverse', () {
      final v = vp(leftDay: 20000.3, top: 7.5, zoom: 1.7);
      expect(v.dayAtX(v.xOfDay(20003.25)), closeTo(20003.25, 1e-9));
      expect(v.hourAtY(v.yOfHour(13.5)), closeTo(13.5, 1e-9));
    });

    test('zoomAt keeps the point under the finger fixed', () {
      final v = vp(zoom: 1);
      const focal = Offset(250, 300);
      final day = v.dayAtX(focal.dx), hour = v.hourAtY(focal.dy);
      final z = v.zoomAt(focal, 2);
      expect(z.zoom, 2);
      expect(z.dayAtX(focal.dx), closeTo(day, 1e-9));
      expect(z.hourAtY(focal.dy), closeTo(hour, 1e-9));
    });

    test('zoom is clamped and vertical pan stays inside the day', () {
      final v = vp().zoomAt(const Offset(100, 100), 1000);
      expect(v.zoom, MapViewport.maxZoom);
      final up = vp().panBy(const Offset(0, 100000));
      expect(up.topHour, -0.25);
      final down = vp().panBy(const Offset(0, -100000));
      expect(down.topHour + down.visibleHours, closeTo(24.25, 1e-9));
    });

    test('horizontal pan is unbounded and moves by days', () {
      final v = vp();
      final moved = v.panBy(Offset(-v.columnWidth * 400, 0));
      expect(moved.leftDay, closeTo(v.leftDay + 400, 1e-9));
    });
  });

  test('a task across midnight is split into one bar per day', () {
    final d = DateTime(2030, 1, 7);
    final v = vp(leftDay: dayNumber(d).toDouble() - 1, top: 0, zoom: 0.5);
    final bars = layoutBars([
      Project(
        id: 'p',
        name: 'P',
        colorValue: 0xFF000000,
        tasks: [
          PlanTask(
            id: 't',
            title: 'Night shift',
            start: DateTime(2030, 1, 7, 22),
            end: DateTime(2030, 1, 8, 6),
            fixed: true,
          ),
          PlanTask(
            id: 'u',
            title: 'Ends at midnight',
            start: DateTime(2030, 1, 7, 20),
            end: DateTime(2030, 1, 8),
            fixed: true,
          ),
        ],
      ),
    ], v);
    expect(bars.where((b) => b.task.id == 't'), hasLength(2));
    expect(bars.where((b) => b.task.id == 'u'), hasLength(1));
    final first = bars.firstWhere((b) => b.task.id == 't');
    final second = bars.lastWhere((b) => b.task.id == 't');
    expect(second.rect.left, greaterThan(first.rect.left));
    expect(first.rect.bottom, closeTo(v.yOfHour(24), 1e-9));
    expect(second.rect.top, closeTo(v.yOfHour(0), 1e-9));
  });
}
