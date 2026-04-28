# Principles App (Flutter)

Flutter rewrite of the Principles app.

Official install page (Android, macOS, iOS, iPadOS): [principles.top](https://principles.top)

## Overview

The app is built with a simple MVVM-style structure:

- `views/`: UI screens.
- `viewmodels/`: state and presentation logic (`ChangeNotifier` + `provider`).
- `services/`: business logic and API-facing services.
- `models/`: app/domain models.
- `core/`: shared infrastructure (network, storage, sync, and theme).
- `app/`: root app wiring (`MultiProvider`, routes, themes).

Main entry point: `lib/main.dart`  
Root app widget: `lib/app/app.dart`

## Features (Current)

- User startup and login flow.
- Goals and habits management.
- Habit details and progress tracking.
- Settings and theme switching.
- Local persistence/sync foundations (`sqflite`, secure storage).
- AI helper/recommendation service integration stubs.

## Tech Stack

- Flutter + Dart
- `provider` for state management
- `dio` for HTTP
- `sqflite` + `path` for local storage
- `flutter_secure_storage` and `shared_preferences` for settings/auth data
- `intl` for formatting/localization helpers

## Prerequisites

- Flutter SDK installed and available in `PATH`
- Dart SDK (comes with Flutter)
- Platform toolchains for your target (Android Studio/Xcode/web)

Project currently targets:

- Dart SDK: `^3.10.8`

## Getting Started

1. Install dependencies:

```bash
flutter pub get
```

2. Verify your local Flutter setup:

```bash
flutter doctor
```

3. Run the app:

```bash
flutter run
```

Useful variants:

```bash
flutter run -d chrome
flutter run -d ios
flutter run -d android
```

## Testing

Run the test suite:

```bash
flutter test
```

Analyze code:

```bash
flutter analyze
```

## Project Structure

```text
lib/
  app/
  core/
    network/
    storage/
    sync/
    theme/
  models/
  services/
  viewmodels/
  views/
```

## Notes

- This app is not published to pub.dev (`publish_to: none`).
- Generated platform folders (`android`, `ios`, `web`, `macos`, `windows`) are included.
