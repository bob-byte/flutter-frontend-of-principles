---
name: flutter-feature
description: Implements Flutter features in Principles following MVVM folders, dual EN/UK l10n, Provider, and Dart MCP tools. Use when adding or changing screens, viewmodels, services, models, ARB strings, navigation, or running analyze/format/tests.
---

# Flutter feature work

## Placement

- UI → `lib/views/` (or `lib/widgets/` for shared)
- State → `lib/viewmodels/` (`ChangeNotifier` + Provider)
- API/business → `lib/services/`
- Domain types → `lib/models/`
- Infra → `lib/core/`
- Register providers/routes in `lib/app/app.dart` (and `router.dart` if needed)

## l10n

- Add keys to both `lib/l10n/app_en.arb` and `lib/l10n/app_uk.arb`
- Run `flutter gen-l10n`; do not hand-edit generated `app_localizations*.dart`
- User-facing copy may stay localized; assistant replies stay English

## Navigation

- Post-auth destination is `HelperView.routeName` (`MainShell`), not a separate `MainView` bypass, so the road guide can run

## Tooling

Prefer MCP `user-dart`: `analyze_files`, `dart_format`, `run_tests`, `hot_reload` / `hot_restart`, `get_runtime_errors`, `get_widget_tree`. Use shell `flutter`/`dart` only when MCP cannot do the job.

## Do not

- Add a second `main()` or scratch files like `lib/test_notif.dart`
- Wrap `GlassScaffold` in extra `Stack`/`OverlayPortal` (road guide overlay owns that)
