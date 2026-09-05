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

  /// True only after a full post-auth hydrate (profile, goals, tasks, habits).
  /// Pre-login splash runs that only load locale leave this false so MainShell
  /// can hydrate again after Google/Apple/email sign-in.
  bool _sessionHydrated = false;

  /// Whether a full authenticated hydrate has completed.
  bool get isSessionHydrated => _sessionHydrated;

  Future<void> ensureLoaded() async {
    if (_sessionHydrated) return;

    final inFlight = _inFlight;
    if (inFlight != null) {
      await inFlight;
      if (_sessionHydrated) return;
    }

    final run = _load();
    _inFlight = run;
    try {
      await run;
    } finally {
      if (identical(_inFlight, run)) {
        _inFlight = null;
      }
    }
  }

  /// Allows a fresh hydrate after logout / account switch.
  void reset() {
    _inFlight = null;
    _sessionHydrated = false;
  }

  Future<void> _load() async {
    var route = await _startup.initialize();
    if (route != StartupNextRoute.helper && !AppConfig.useLocalData) {
      // `initialize()` caches the pre-login route. After Google/Apple/email
      // sign-in that cache is stale until markSignedIn(); recover via token.
      if (await _startup.hasAuthenticatedSession()) {
        _startup.markSignedIn();
        route = StartupNextRoute.helper;
      } else {
        try {
          await _settings.loadLocale();
        } catch (_) {}
        // Not authenticated yet — MainShell after login will call ensureLoaded
        // again and run the full hydrate below.
        return;
      }
    }

    // Paint cached SQLite/prefs data first so tabs are not blank while sync runs.
    await _hydrateFromLocal();

    try {
      await _orchestrator.run(SyncTrigger.startup);
    } catch (_) {}

    // Refresh after bootstrap merge — silent so existing UI is not blanked.
    await _hydrateFromLocal();
    _sessionHydrated = true;
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
