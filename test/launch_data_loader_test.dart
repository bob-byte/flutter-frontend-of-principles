import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/launch_data_loader.dart';
import 'package:principles_app/core/sync/sync_orchestrator.dart';
import 'package:principles_app/core/sync/sync_run_result.dart';
import 'package:principles_app/core/sync/sync_trigger.dart';
import 'package:principles_app/viewmodels/goals_viewmodel.dart';
import 'package:principles_app/viewmodels/habit_progress_viewmodel.dart';
import 'package:principles_app/viewmodels/settings_viewmodel.dart';
import 'package:principles_app/viewmodels/startup_viewmodel.dart';
import 'package:principles_app/viewmodels/tasks_viewmodel.dart';

class _FakeStartup extends Fake implements StartupViewModel {
  _FakeStartup(this.routes, {this.authenticated = false});

  final List<StartupNextRoute> routes;
  final bool authenticated;
  int calls = 0;
  int markSignedInCalls = 0;
  StartupNextRoute? _signedInOverride;

  @override
  Future<StartupNextRoute> initialize() async {
    if (_signedInOverride != null) return _signedInOverride!;
    final index = calls < routes.length ? calls : routes.length - 1;
    calls += 1;
    return routes[index];
  }

  @override
  void markSignedIn() {
    markSignedInCalls += 1;
    _signedInOverride = StartupNextRoute.helper;
  }

  @override
  Future<bool> hasAuthenticatedSession() async => authenticated;
}

class _FakeOrchestrator extends Fake implements SyncOrchestrator {
  int runs = 0;

  @override
  Future<SyncRunResult> run(SyncTrigger trigger) async {
    runs += 1;
    return const SyncRunResult(status: SyncRunStatus.succeeded);
  }
}

class _FakeGoals extends Fake implements GoalsViewModel {
  int loads = 0;

  @override
  Future<void> load({bool silent = false}) async {
    loads += 1;
  }
}

class _FakeTasks extends Fake implements TasksViewModel {
  int loads = 0;

  @override
  Future<void> load({bool silent = false}) async {
    loads += 1;
  }
}

class _FakeHabits extends Fake implements HabitProgressViewModel {
  int loads = 0;

  @override
  Future<void> load({bool silent = false, bool syncRemote = true}) async {
    loads += 1;
  }
}

class _FakeSettings extends Fake implements SettingsViewModel {
  int loads = 0;
  int localeLoads = 0;

  @override
  Future<void> load({bool silent = false}) async {
    loads += 1;
  }

  @override
  Future<void> loadLocale() async {
    localeLoads += 1;
  }
}

void main() {
  test('pre-auth ensureLoaded does not mark session hydrated', () async {
    final startup = _FakeStartup([StartupNextRoute.login]);
    final settings = _FakeSettings();
    final loader = LaunchDataLoader(
      startup: startup,
      orchestrator: _FakeOrchestrator(),
      goals: _FakeGoals(),
      tasks: _FakeTasks(),
      habits: _FakeHabits(),
      settings: settings,
    );

    await loader.ensureLoaded();

    expect(loader.isSessionHydrated, isFalse);
    expect(settings.localeLoads, 1);
    expect(settings.loads, 0);
  });

  test('second ensureLoaded after login hydrates settings profile', () async {
    final startup = _FakeStartup([
      StartupNextRoute.login,
      StartupNextRoute.helper,
    ]);
    final settings = _FakeSettings();
    final goals = _FakeGoals();
    final orchestrator = _FakeOrchestrator();
    final loader = LaunchDataLoader(
      startup: startup,
      orchestrator: orchestrator,
      goals: goals,
      tasks: _FakeTasks(),
      habits: _FakeHabits(),
      settings: settings,
    );

    await loader.ensureLoaded();
    expect(loader.isSessionHydrated, isFalse);

    await loader.ensureLoaded();

    expect(loader.isSessionHydrated, isTrue);
    expect(settings.loads, greaterThan(0));
    expect(goals.loads, greaterThan(0));
    expect(orchestrator.runs, 1);
  });

  test(
    'hydrates when initialize is stale login but a session token exists',
    () async {
      final startup = _FakeStartup([
        StartupNextRoute.login,
      ], authenticated: true);
      final settings = _FakeSettings();
      final goals = _FakeGoals();
      final tasks = _FakeTasks();
      final habits = _FakeHabits();
      final loader = LaunchDataLoader(
        startup: startup,
        orchestrator: _FakeOrchestrator(),
        goals: goals,
        tasks: tasks,
        habits: habits,
        settings: settings,
      );

      await loader.ensureLoaded();

      expect(loader.isSessionHydrated, isTrue);
      expect(startup.markSignedInCalls, 1);
      expect(goals.loads, greaterThan(0));
      expect(tasks.loads, greaterThan(0));
      expect(habits.loads, greaterThan(0));
      expect(settings.loads, greaterThan(0));
    },
  );

  test('reset allows hydrate again', () async {
    final startup = _FakeStartup([StartupNextRoute.helper]);
    final settings = _FakeSettings();
    final loader = LaunchDataLoader(
      startup: startup,
      orchestrator: _FakeOrchestrator(),
      goals: _FakeGoals(),
      tasks: _FakeTasks(),
      habits: _FakeHabits(),
      settings: settings,
    );

    await loader.ensureLoaded();
    expect(loader.isSessionHydrated, isTrue);
    final loadsAfterFirst = settings.loads;

    loader.reset();
    expect(loader.isSessionHydrated, isFalse);

    await loader.ensureLoaded();
    expect(loader.isSessionHydrated, isTrue);
    expect(settings.loads, greaterThan(loadsAfterFirst));
  });
}
