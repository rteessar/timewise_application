# TimeWise

Plan your time on a **map**. TimeWise lays your projects out as lanes on an
endless, zoomable timeline: pinch (or scroll) to zoom from months down to
hours, drag to pan, tap a task to act on it, long-press a lane to drop a new
task exactly where you pressed.

## Features
- **Map** – pan/zoom timeline canvas, one lane per project, overlapping tasks
  auto-stack, live "now" line, zoom presets, jump to today.
- **Dashboard** – today, overdue, progress per project.
- **Project composer** – name, colour and tasks for a project.
- **Settings** – light/dark/system theme, clear data.
- Everything is stored locally (`shared_preferences`), no account needed.

## Structure
```
lib/
  core/        theme, router, constants
  features/
    planner/   domain models, persistence, Riverpod state, task editor
    timeline/  the map: layout, painter, gestures
    dashboard/ project_composer/ settings/ shell/
```

## Run
```
flutter pub get
flutter run
flutter test
```
