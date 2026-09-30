import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timewise_application/app.dart';
import 'package:timewise_application/features/planner/application/planner_controller.dart';
import 'package:timewise_application/features/planner/domain/models.dart';
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

  testWidgets('empty map offers to create a project and persists it', (
    tester,
  ) async {
    final container = await _boot(tester);
    expect(find.text('Your map is empty'), findsOneWidget);

    await tester.tap(find.text('Create project'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Launch');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(container.read(plannerProvider).single.name, 'Launch');
    expect(find.text('Your map is empty'), findsNothing);
    expect(find.text('Task'), findsOneWidget); // add-task FAB on the map
  });

  testWidgets('map pans and zooms without errors', (tester) async {
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
              ),
            ],
          ),
        );
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
