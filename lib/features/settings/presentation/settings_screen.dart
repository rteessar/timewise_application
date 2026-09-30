import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../planner/application/planner_controller.dart';
import '../../planner/domain/habit_profile.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode),
                label: Text('Dark'),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).set(s.first),
          ),
          const SizedBox(height: 32),
          const SizedBox(height: 32),
          const _HabitSection(),
          const SizedBox(height: 32),
          Text('Data', style: Theme.of(context).textTheme.titleMedium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Clear all projects'),
            subtitle: const Text(
              'Removes every project and task from this device',
            ),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear everything?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                final n = ref.read(plannerProvider.notifier);
                for (final p in [...ref.read(plannerProvider)]) {
                  n.deleteProject(p.id);
                }
              }
            },
          ),
          const SizedBox(height: 32),
          const Center(child: Text('${AppConstants.appName} 1.0.0')),
        ],
      ),
    );
  }
}

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class _HabitSection extends ConsumerWidget {
  const _HabitSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(habitProvider);
    final n = ref.read(habitProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    Widget hourPicker(
      String label,
      int value,
      void Function(int) onChanged,
      List<int> options,
    ) => Expanded(
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final h in options)
            DropdownMenuItem(
              value: h,
              child: Text('${h.toString().padLeft(2, '0')}:00'),
            ),
        ],
        onChanged: (v) => onChanged(v!),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Planning', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            hourPicker(
              'Day starts',
              p.workStartHour,
              (v) => n.update(
                p.copyWith(
                  workStartHour: v,
                  workEndHour: p.workEndHour <= v ? v + 1 : p.workEndHour,
                ),
              ),
              [for (var h = 5; h <= 20; h++) h],
            ),
            const SizedBox(width: 12),
            hourPicker(
              'Day ends',
              p.workEndHour,
              (v) => n.update(p.copyWith(workEndHour: v)),
              [for (var h = p.workStartHour + 1; h <= 23; h++) h],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(_dayNames[d - 1]),
                selected: p.workDays.contains(d),
                onSelected: (on) {
                  final days = {...p.workDays};
                  on ? days.add(d) : days.remove(d);
                  n.update(p.copyWith(workDays: days));
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Break between tasks'),
            const Spacer(),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('0')),
                ButtonSegment(value: 5, label: Text('5')),
                ButtonSegment(value: 10, label: Text('10')),
                ButtonSegment(value: 15, label: Text('15')),
              ],
              selected: {p.bufferMinutes},
              onSelectionChanged: (s) =>
                  n.update(p.copyWith(bufferMinutes: s.first)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'What TimeWise has learned',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          p.signals == 0
              ? 'Nothing yet. Finish planned tasks on time, or drag them to '
                    'hours you prefer, and the planner adapts.'
              : 'Based on ${p.signals} signal${p.signals == 1 ? '' : 's'} '
                    '(tasks you finished and times you moved). Taller = better hour for you.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var h = 6; h < 23; h++)
                Expanded(
                  child: Tooltip(
                    message: '${h.toString().padLeft(2, '0')}:00',
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      height:
                          70 *
                          (p.weightAt(h) / HabitProfile.maxWeight).clamp(
                            0.05,
                            1.0,
                          ),
                      decoration: BoxDecoration(
                        color: h >= p.workStartHour && h < p.workEndHour
                            ? scheme.primary
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '06',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
            Text(
              '12',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
            Text(
              '22',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        if (p.signals > 0)
          TextButton(
            onPressed: () => n.update(p.resetLearning()),
            child: const Text('Reset what it learned'),
          ),
      ],
    );
  }
}
