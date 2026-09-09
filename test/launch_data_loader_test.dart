import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/launch_data_loader.dart';
import 'package:principles_app/core/network/server_required_retry.dart';
import 'package:provider/provider.dart';
import 'package:principles_app/core/sync/sync_orchestrator.dart';
import 'package:principles_app/core/sync/sync_run_result.dart';
import 'package:principles_app/core/sync/sync_trigger.dart';
import 'package:principles_app/viewmodels/goals_viewmodel.dart';
import 'package:principles_app/viewmodels/habit_progress_viewmodel.dart';
import 'package:principles_app/viewmodels/helper_viewmodel.dart';
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

class _FailingThenOkOrchestrator extends Fake implements SyncOrchestrator {
  int runs = 0;

  @override
  Future<SyncRunResult> run(SyncTrigger trigger) async {
    runs += 1;
    if (runs == 1) {
      return const SyncRunResult(status: SyncRunStatus.failed);
    }
    return const SyncRunResult(status: SyncRunStatus.succeeded);
  }
}

class _NotFoundThenOkOrchestrator extends Fake implements SyncOrchestrator {
  int runs = 0;

  @override
  Future<SyncRunResult> run(SyncTrigger trigger) async {
    runs += 1;
    if (runs == 1) {
      return const SyncRunResult(
        status: SyncRunStatus.failed,
        error: ServerTechnicalWorkException(statusCode: 404),
      );
    }
    return const SyncRunResult(status: SyncRunStatus.succeeded);
  }
}

class _HangingOrchestrator extends Fake implements SyncOrchestrator {
  @override
  Future<SyncRunResult> run(SyncTrigger trigger) {
    return Completer<SyncRunResult>().future;
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

class _FakeHelper extends Fake implements HelperViewModel {
  int loads = 0;

  @override
  Future<void> load({bool silent = false}) async {
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
  test('reset clears reminder-restore and bootstrap flags', () async {
    final loader = LaunchDataLoader(
      startup: _FakeStartup([StartupNextRoute.helper]),
      orchestrator: _FakeOrchestrator(),
      goals: _FakeGoals(),
      tasks: _FakeTasks(),
      habits: _FakeHabits(),
      settings: _FakeSettings(),
    );

    await loader.ensureLoaded();
    loader.markReminderRestoreDone();
    expect(loader.isSyncGateComplete, isTrue);

    loader.reset();
    expect(loader.isBootstrapComplete, isFalse);
    expect(loader.hasCompletedReminderRestore, isFalse);
    expect(loader.isSyncGateComplete, isFalse);
  });

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
    expect(loader.isBootstrapComplete, isTrue);
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

  test('syncAndHydrate after session re-syncs and reloads tabs', () async {
    final startup = _FakeStartup([StartupNextRoute.helper]);
    final orchestrator = _FakeOrchestrator();
    final tasks = _FakeTasks();
    final loader = LaunchDataLoader(
      startup: startup,
      orchestrator: orchestrator,
      goals: _FakeGoals(),
      tasks: tasks,
      habits: _FakeHabits(),
      settings: _FakeSettings(),
    );

    await loader.ensureLoaded();
    final runsAfterStart = orchestrator.runs;
    final taskLoads = tasks.loads;

    await loader.syncAndHydrate(SyncTrigger.resume);

    expect(orchestrator.runs, runsAfterStart + 1);
    expect(tasks.loads, greaterThan(taskLoads));
  });

  test('syncAndHydrate skipIfRecent does not run orchestrator again', () async {
    final startup = _FakeStartup([StartupNextRoute.helper]);
    final orchestrator = _FakeOrchestrator();
    final loader = LaunchDataLoader(
      startup: startup,
      orchestrator: orchestrator,
      goals: _FakeGoals(),
      tasks: _FakeTasks(),
      habits: _FakeHabits(),
      settings: _FakeSettings(),
    );

    await loader.ensureLoaded();
    final runsAfterStart = orchestrator.runs;

    final result = await loader.syncAndHydrate(
      SyncTrigger.resume,
      skipIfRecent: true,
    );

    expect(result.status, SyncRunStatus.skippedThrottled);
    expect(orchestrator.runs, runsAfterStart);
  });

  test('failed startup sync does not throttle catch-up', () async {
    final startup = _FakeStartup([StartupNextRoute.helper]);
    final orchestrator = _FailingThenOkOrchestrator();
    final loader = LaunchDataLoader(
      startup: startup,
      orchestrator: orchestrator,
      goals: _FakeGoals(),
      tasks: _FakeTasks(),
      habits: _FakeHabits(),
      settings: _FakeSettings(),
    );

    await loader.ensureLoaded();
    expect(orchestrator.runs, 1);

    final result = await loader.syncAndHydrate(
      SyncTrigger.resume,
      skipIfRecent: true,
    );

    expect(result.status, isNot(SyncRunStatus.skippedThrottled));
    expect(orchestrator.runs, 2);
  });

  test('bootstrap hydrate reloads chats after merge', () async {
    final helper = _FakeHelper();
    final loader = LaunchDataLoader(
      startup: _FakeStartup([StartupNextRoute.helper]),
      orchestrator: _FakeOrchestrator(),
      goals: _FakeGoals(),
      tasks: _FakeTasks(),
      habits: _FakeHabits(),
      settings: _FakeSettings(),
      helper: helper,
    );

    await loader.ensureLoaded();

    expect(loader.isSessionHydrated, isTrue);
    // Local paint, then again after bootstrap merge.
    expect(helper.loads, 2);
  });

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

  test('bootstrap sync timeout still marks session hydrated', () async {
    final loader = LaunchDataLoader(
      startup: _FakeStartup([StartupNextRoute.helper]),
      orchestrator: _HangingOrchestrator(),
      goals: _FakeGoals(),
      tasks: _FakeTasks(),
      habits: _FakeHabits(),
      settings: _FakeSettings(),
      bootstrapSyncTimeout: const Duration(milliseconds: 20),
    );

    await loader.ensureLoaded().timeout(const Duration(seconds: 2));
    expect(loader.isSessionHydrated, isTrue);
    expect(loader.isBootstrapComplete, isTrue);
  });

  test('SyncGate waits for bootstrap even after local paint', () async {
    final loader = LaunchDataLoader(
      startup: _FakeStartup([StartupNextRoute.helper]),
      orchestrator: _HangingOrchestrator(),
      goals: _FakeGoals(),
      tasks: _FakeTasks(),
      habits: _FakeHabits(),
      settings: _FakeSettings(),
      bootstrapSyncTimeout: const Duration(seconds: 30),
    );

    await loader.ensureLocalSession().timeout(const Duration(seconds: 2));
    expect(loader.isSessionHydrated, isTrue);
    expect(loader.isBootstrapComplete, isFalse);

    await expectLater(
      loader.ensureLoaded().timeout(const Duration(milliseconds: 50)),
      throwsA(isA<TimeoutException>()),
    );
    expect(loader.isBootstrapComplete, isFalse);
  });

  testWidgets('shell tab reload skips when there is no loader', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          expect(launchSessionAlreadyHydrated(context), isFalse);
          expect(shouldSkipShellTabReload(context), isTrue);
          return const SizedBox.shrink();
        },
      ),
    );
  });

  testWidgets('launchSessionAlreadyHydrated follows the loader flag', (
    tester,
  ) async {
    final loader = LaunchDataLoader(
      startup: _FakeStartup([StartupNextRoute.helper]),
      orchestrator: _FakeOrchestrator(),
      goals: _FakeGoals(),
      tasks: _FakeTasks(),
      habits: _FakeHabits(),
      settings: _FakeSettings(),
    );
    await tester.runAsync(loader.ensureLoaded);

    await tester.pumpWidget(
      Provider<LaunchDataLoader>.value(
        value: loader,
        child: Builder(
          builder: (context) {
            expect(launchSessionAlreadyHydrated(context), isTrue);
            expect(shouldSkipShellTabReload(context), isTrue);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  test('ensureLocalSession returns before a hanging bootstrap sync', () async {
    final loader = LaunchDataLoader(
      startup: _FakeStartup([StartupNextRoute.helper]),
      orchestrator: _HangingOrchestrator(),
      goals: _FakeGoals(),
      tasks: _FakeTasks(),
      habits: _FakeHabits(),
      settings: _FakeSettings(),
      bootstrapSyncTimeout: const Duration(seconds: 30),
    );

    await loader.ensureLocalSession().timeout(const Duration(seconds: 2));
    expect(loader.isSessionHydrated, isTrue);
  });

  test(
    'startup 404 is stored and retryStartupSyncIfServerDown retries',
    () async {
      final orchestrator = _NotFoundThenOkOrchestrator();
      final loader = LaunchDataLoader(
        startup: _FakeStartup([StartupNextRoute.helper]),
        orchestrator: orchestrator,
        goals: _FakeGoals(),
        tasks: _FakeTasks(),
        habits: _FakeHabits(),
        settings: _FakeSettings(),
      );

      await loader.ensureLoaded();
      expect(orchestrator.runs, 1);
      expect(isServerTechnicalWork(loader.lastRemoteSyncResult?.error), isTrue);

      var prompts = 0;
      await loader.retryStartupSyncIfServerDown(
        ServerRequiredRetry(
          prompt: () async {
            prompts += 1;
            return true;
          },
        ),
      );

      expect(prompts, 1);
      expect(orchestrator.runs, 2);
      expect(loader.lastRemoteSyncResult?.status, SyncRunStatus.succeeded);
    },
  );

  test('retryStartupSyncIfServerDown stops when the user cancels', () async {
    final orchestrator = _NotFoundThenOkOrchestrator();
    final loader = LaunchDataLoader(
      startup: _FakeStartup([StartupNextRoute.helper]),
      orchestrator: orchestrator,
      goals: _FakeGoals(),
      tasks: _FakeTasks(),
      habits: _FakeHabits(),
      settings: _FakeSettings(),
    );

    await loader.ensureLoaded();
    await loader.retryStartupSyncIfServerDown(
      ServerRequiredRetry(prompt: () async => false),
    );

    expect(orchestrator.runs, 1);
    expect(isServerTechnicalWork(loader.lastRemoteSyncResult?.error), isTrue);
  });
}
