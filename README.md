# TimeWise

Plan your time so none of it is wasted. TimeWise maps your week, finds the
free gaps between your commitments, and places your tasks in them, learning
which hours suit you.

## How it works
- **Map** – a 2D canvas of your time. Drag in any direction: sideways moves
  through days without limit, up/down moves through the hours of the day.
  Pinch (or Ctrl/Cmd + scroll) to zoom from single hours out to several
  weeks; fling to glide; scroll or two-finger swipe pans. Green is free time
  (brighter at your best hours), hatched orange is free time too short to
  use, blocks are commitments. Tap an empty slot to add a fixed event, tap a
  block to act on it.
- **Flexible tasks** – give a task an estimate, optional deadline and priority
  and choose *Find me a slot*. **Auto-plan** places every flexible task into
  free working time: urgent first, packed tightly against other commitments,
  no unusable slivers, never on top of a fixed event. Anything that does not
  fit is listed with the reason. Every run can be undone.
- **It learns, on your device.** Finishing a planned task inside its slot
  reinforces that hour; moving a planned task to another hour steers future
  plans away from the old one and towards the new one. See what it learned
  (and reset it) in Settings.
- **Today** – free time left, time lost to gaps, today's tasks, overdue items.
- **Timeline** – the zoomable canvas (years to hours), one lane per project.
- **Settings** – working hours and days, breaks between tasks, theme.
- Everything is stored locally (`shared_preferences`); no account needed.

## Structure
```
lib/
  core/        theme, router, constants
  features/
    planner/   domain (tasks, habit profile, AutoPlanner), state, task editor
    map/       the pannable, zoomable time map
    tasks/     inbox of tasks waiting for a slot
    timeline/  zoomable project timeline
    dashboard/ project_composer/ settings/ shell/
```
The planner (`planner/domain/auto_planner.dart`) is plain Dart with no UI
dependencies and is covered by unit tests.

## Run
```
flutter pub get
flutter run
flutter test
```
