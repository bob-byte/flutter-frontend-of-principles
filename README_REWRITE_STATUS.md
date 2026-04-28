# Flutter Rewrite Status

This Flutter app now includes:

- App bootstrap, routing, DI, MVVM folder layout.
- Local DB and sync queue primitives.
- Startup + login flow.
- Habit editing and AI recommended habits.
- AI chat with streaming and cancellation.
- Goals and progress views.
- Theme switching (light, dark black+orange, system).
- Placeholders for reminders, ads, and chart services.

## Next hardening steps

- Replace mock AI/service internals with real backend calls.
- Map all SQLite tables from existing migrations one-by-one.
- Implement full queue reconciliation against server bootstrap snapshots.
- Add reminder scheduling integration package and permissions wiring.
- Add widget/integration tests for critical user flows.
