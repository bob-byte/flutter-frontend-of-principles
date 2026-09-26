# Principles (Flutter)

Flutter rewrite of the Principles habit/goal app.

Official install page (Android, macOS, iOS, iPadOS): [principles.top](https://principles.top)

Backend is .NET 8 (`SET.WebAPI`) in [`backend/`](backend/).

## Core loop

1. Define a **goal**
2. Attach **habits** that automate progress (optionally via AI recommendations)
3. Complete habits; inspect detail (progress, streaks, stability)
4. Use **Tasks** for one-off work and to keep today's habits visible
5. Use **AI Helper** for support — not the primary recommendation entry point
6. Settings (profile, slogan, mission) feed AI habit recommendations

## Shell

Tab order: Chat · Goals · **Tasks** (center, default) · Habits · Settings

- Pre-login: App Benefits carousel
- Post-login: spotlight road guide once per device (replay from Settings → About)
- Daily progress reminder (Tasks app bar): check-in for goals, habits, and tasks; notification opens Tasks today
- Home-screen calendar widgets (month / week / today) show scheduled tasks and habits due that day

## Architecture

MVVM-style layout under `lib/`:

| Folder | Role |
|--------|------|
| `views/` | Screens |
| `viewmodels/` | State and presentation (`ChangeNotifier` + Provider) |
| `services/` | Business logic and API-facing services |
| `models/` | Domain models |
| `core/` | Infra (network, storage, sync, theme, home widgets, deep links, reminders) |
| `app/` | Root wiring (`MultiProvider`, routes, themes) |
| `widgets/` | Shared UI |

Entry: `lib/main.dart` → `lib/app/app.dart`

Local SQLite (`sqflite`) plus a sync queue to the .NET WebAPI. Sync prefers incremental `GET /sync/changes?since=…` when a cursor exists; otherwise `GET /sync/bootstrap`. Offline-capable CRUD enqueues first, then syncs when online.

## Features

- Auth (email, Apple, Google) and startup / SyncGate bootstrap
- Goals with nested habits; Habits tab as a flat filtered list
- Habit detail (calendar, streaks, stability) and edit as normal pages
- Tasks with checklists (subtasks), live-save while editing, repeats, and reminders
- AI Helper chat history (synced) and task AI assist
- Local notifications (including constant task/habit reminders) and deep links from widgets / notifications
- Themes, alternate app icons, EN/UK localization
- Completion celebration sound + burst animation

## Tech stack

- Flutter / Dart SDK `^3.10.8`
- Provider, Dio, sqflite
- `flutter_secure_storage`, `shared_preferences`
- `flutter_local_notifications`, `home_widget`
- `liquid_glass_widgets`, l10n via `lib/l10n/app_en.arb` and `app_uk.arb` (`flutter gen-l10n`)

AI chat and task assist go through the backend (`POST /api/ai/chat`, `POST /api/ai/parse-task`). Set `AI_API_KEY` on the server only — no OpenAI key in the Flutter app.

## Prerequisites

- Flutter SDK on `PATH` (Dart comes with Flutter)
- Platform toolchains for your target (Android Studio / Xcode)

## Getting started

```bash
flutter pub get
flutter doctor
flutter run
```

Useful targets:

```bash
flutter run -d chrome
flutter run -d ios
flutter run -d android
flutter run -d macos
```

## Testing and analysis

```bash
flutter test
flutter analyze
```

After editing ARB strings:

```bash
flutter gen-l10n
```

## Project structure

```text
lib/
  app/
  core/
    deep_link/
    home_widget/
    network/
    reminder/
    storage/
    sync/
    theme/
  l10n/
  models/
  services/
  viewmodels/
  views/
  widgets/
backend/          # .NET WebAPI (separate git root)
```

## Notes

- Not published to pub.dev (`publish_to: none`).
- Platform folders (`android`, `ios`, `macos`, `windows`, `web`) are included.
- iOS/macOS home widgets need App Group `group.com.set.principles`.
- Cursor project rules live in `.cursor/rules/`; agent skills in `.cursor/skills/`.
