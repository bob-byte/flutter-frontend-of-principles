import 'config/app_config.dart';
import 'sync/sync_orchestrator.dart';
import 'sync/sync_trigger.dart';
import '../viewmodels/goals_viewmodel.dart';
import '../viewmodels/habit_progress_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../viewmodels/startup_viewmodel.dart';
import '../viewmodels/tasks_viewmodel.dart';

/// Prefetches session, sync, and the first screens' data while the launch
/// video is playing so the UI is ready when the overlay goes away.
class LaunchDataLoader {
  LaunchDataLoader({
    required StartupViewModel startup,
    required SyncOrchestrator orchestrator,
    required GoalsViewModel goals,
    required TasksViewModel tasks,
    required HabitProgressViewModel habits,
    required SettingsViewModel settings,
  }) : _startup = startup,
       _orchestrator = orchestrator,
       _goals = goals,
       _tasks = tasks,
       _habits = habits,
       _settings = settings;

  final StartupViewModel _startup;
  final SyncOrchestrator _orchestrator;
  final GoalsViewModel _goals;
  final TasksViewModel _tasks;
  final HabitProgressViewModel _habits;
  final SettingsViewModel _settings;

  Future<void>? _inFlight;

  Future<void> ensureLoaded() => _inFlight ??= _load();

  /// Allows a fresh hydrate after logout / account switch.
  void reset() {
    _inFlight = null;
  }

  Future<void> _load() async {
    final route = await _startup.initialize();
    if (route != StartupNextRoute.helper && !AppConfig.useLocalData) {
      try {
        await _settings.loadLocale();
      } catch (_) {}
      return;
    }

    // Paint cached SQLite/prefs data first so tabs are not blank while sync runs.
    await _hydrateFromLocal();

    try {
      await _orchestrator.run(SyncTrigger.startup);
    } catch (_) {}

    // Refresh after bootstrap merge — silent so existing UI is not blanked.
    await _hydrateFromLocal();
  }

  Future<void> _hydrateFromLocal() {
    return Future.wait([
      _safe(() => _goals.load(silent: true)),
      _safe(() => _tasks.load(silent: true)),
      // Orchestrator already merges habits; skip the extra /habits/inprogress call.
      _safe(() => _habits.load(silent: true, syncRemote: false)),
      _safe(() => _settings.load(silent: true)),
    ]);
  }

  Future<void> _safe(Future<void> Function() load) async {
    try {
      await load();
    } catch (_) {}
  }
}
