# System patterns

## App structure

- Flutter MVVM-ish: `views/` + `viewmodels/` + `services/`
- Shell: `MainShell` + `MainShellController` tab indices
- Local SQLite + sync queue to .NET WebAPI (`backend/`)

## Road guide

- `RoadGuideController` + `RoadGuideKeys` / steps + `RoadGuideOverlay` as `OverlayEntry`
- Demo entities: negative goal/habit ids, string task id
- Persistence: SharedPreferences device flag + `User.HasSeenRoadGuide` on backend
- Pushed routes during tour: Edit Habit (recommendations), Habit Detail (preview via `showPreview`)

## Goals ↔ habits

- Match by `targetGoalId` or case-insensitive `targetGoal` name (`habitsForGoal` / `habitsUnassignedToGoals`)
