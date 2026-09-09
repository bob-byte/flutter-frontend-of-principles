import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'network/server_required_retry.dart';
import 'sync/sync_orchestrator.dart';
import 'sync/sync_run_result.dart';
import 'sync/sync_trigger.dart';
import '../viewmodels/goals_viewmodel.dart';
import '../viewmodels/habit_progress_viewmodel.dart';
import '../viewmodels/helper_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../viewmodels/startup_viewmodel.dart';
import '../viewmodels/tasks_viewmodel.dart';

/// Whether [LaunchDataLoader] already painted SQLite into the tab VMs.
bool launchSessionAlreadyHydrated(BuildContext context) {
  try {
    return context.read<LaunchDataLoader>().isSessionHydrated;
  } on ProviderNotFoundException {
    return false;
  }
}

/// Skip Goals/Tasks/Habits `load()` after hydrate, and in widget tests
/// that have no loader (they must not open a second SQLite handle).
bool shouldSkipShellTabReload(BuildContext context) {
  try {
    return context.read<LaunchDataLoader>().isSessionHydrated;
  } on ProviderNotFoundException {
    return true;
  }
}

/// How long a successful remote sync suppresses another catch-up.
const kSessionSyncThrottle = Duration(seconds: 15);

/// Cap bootstrap sync so a stalled network call cannot block forever.
const kBootstrapSyncTimeout = Duration(seconds: 45);

/// How long SyncGate waits for a local SQLite paint before waiting on merge.
const kLocalSessionTimeout = Duration(seconds: 8);

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
    HelperViewModel? helper,
    this.syncThrottle = kSessionSyncThrottle,
    this.bootstrapSyncTimeout = kBootstrapSyncTimeout,
    this.localSessionTimeout = kLocalSessionTimeout,
  }) : _startup = startup,
       _orchestrator = orchestrator,
       _goals = goals,
       _tasks = tasks,
       _habits = habits,
       _settings = settings,
       _helper = helper;

  final StartupViewModel _startup;
  final SyncOrchestrator _orchestrator;
  final GoalsViewModel _goals;
  final TasksViewModel _tasks;
  final HabitProgressViewModel _habits;
  final SettingsViewModel _settings;
  final HelperViewModel? _helper;
  final Duration syncThrottle;
  final Duration bootstrapSyncTimeout;
  final Duration localSessionTimeout;

  Future<void>? _inFlight;
  Future<SyncRunResult>? _refreshInFlight;
  DateTime? _lastRemoteSyncAt;
  Completer<void>? _localReady;
  SyncRunResult? lastRemoteSyncResult;

  /// Bumped by [reset] so an orphaned in-flight [_load] cannot mark hydrated.
  int _epoch = 0;

  /// True after the first authenticated local paint (profile, goals, tasks,
  /// habits, chats). Pre-login splash runs that only load locale leave this
  /// false so MainShell can hydrate again after Google/Apple/email sign-in.
  bool _sessionHydrated = false;

  /// True after startup bootstrap sync finished (or timed out / failed).
  /// SyncGate stays up until this is true — cold start and post-sign-in.
  bool _bootstrapComplete = false;

  /// True after SyncGate finished reminder restore for this session.
  bool _reminderRestoreDone = false;

  /// Whether a full authenticated hydrate has completed.
  bool get isSessionHydrated => _sessionHydrated;

  /// Whether the first authenticated bootstrap sync has finished.
  ///
  /// Distinct from [isSessionHydrated]: local paint flips hydrated early so
  /// tabs can skip reload, but SyncGate must wait for this flag.
  bool get isBootstrapComplete => _bootstrapComplete;

  /// Whether SyncGate already restored reminders for this signed-in session.
  bool get hasCompletedReminderRestore => _reminderRestoreDone;

  /// SyncGate can dismiss only after bootstrap and reminder restore.
  bool get isSyncGateComplete =>
      _bootstrapComplete && _reminderRestoreDone;

  void markReminderRestoreDone() {
    _reminderRestoreDone = true;
  }

  /// Local SQLite/prefs paint only — does not wait for bootstrap merge.
  Future<void> ensureLocalSession() async {
    if (_sessionHydrated) return;
    _startLoadIfNeeded();
    final ready = _localReady;
    if (ready == null) return;
    try {
      await ready.future.timeout(localSessionTimeout);
    } on TimeoutException {
      // Continue with whatever is already in memory.
    }
  }

  Future<void> ensureLoaded() async {
    if (_bootstrapComplete) return;

    _startLoadIfNeeded();
    final run = _inFlight;
    if (run != null) {
      await run;
    }
  }

  void _startLoadIfNeeded() {
    if (_bootstrapComplete || _inFlight != null) return;
    final epoch = _epoch;
    final run = _load();
    _inFlight = run;
    _localReady ??= Completer<void>();
    run.whenComplete(() {
      if (identical(_inFlight, run)) {
        _inFlight = null;
      }
      if (epoch == _epoch) {
        _completeLocalReady();
      }
    });
  }

  /// Allows a fresh hydrate after logout / account switch.
  void reset() {
    _epoch++;
    _inFlight = null;
    _refreshInFlight = null;
    _lastRemoteSyncAt = null;
    lastRemoteSyncResult = null;
    _sessionHydrated = false;
    _bootstrapComplete = false;
    _reminderRestoreDone = false;
    if (_localReady != null && !_localReady!.isCompleted) {
      _localReady!.complete();
    }
    _localReady = Completer<void>();
  }

  /// Pulls server changes and refreshes in-memory lists.
  ///
  /// Needed for multi-device use: Mac/iPhone keep an already-hydrated session
  /// and would otherwise never see tasks created on the other device.
  Future<SyncRunResult> syncAndHydrate(
    SyncTrigger trigger, {
    bool skipIfRecent = false,
  }) async {
    final loading = _inFlight;
    if (loading != null) {
      await loading;
      if (_sessionHydrated) {
        return const SyncRunResult(status: SyncRunStatus.succeeded);
      }
    }

    if (!_sessionHydrated) {
      await ensureLoaded();
      return _sessionHydrated
          ? const SyncRunResult(status: SyncRunStatus.succeeded)
          : const SyncRunResult(status: SyncRunStatus.skippedNoAuth);
    }

    if (skipIfRecent && _recentlySynced) {
      // Skip SQLite → VM reload; UI already has session data.
      return const SyncRunResult(status: SyncRunStatus.skippedThrottled);
    }

    final existing = _refreshInFlight;
    if (existing != null) {
      await existing;
      return const SyncRunResult(status: SyncRunStatus.skippedAlreadyRunning);
    }

    final run = _syncAndHydrateBody(trigger);
    _refreshInFlight = run;
    try {
      return await run;
    } finally {
      if (identical(_refreshInFlight, run)) {
        _refreshInFlight = null;
      }
    }
  }

  bool get _recentlySynced {
    final at = _lastRemoteSyncAt;
    return at != null && DateTime.now().difference(at) < syncThrottle;
  }

  Future<SyncRunResult> _syncAndHydrateBody(SyncTrigger trigger) async {
    late final SyncRunResult result;
    try {
      result = await _orchestrator.run(trigger);
    } catch (e) {
      result = SyncRunResult(status: SyncRunStatus.failed, error: e);
    }
    lastRemoteSyncResult = result;
    if (result.status == SyncRunStatus.succeeded) {
      _lastRemoteSyncAt = DateTime.now();
      await _hydrateFromLocal();
    }
    return result;
  }

  Future<void> _load() async {
    final epoch = _epoch;
    var route = await _startup.initialize();
    if (epoch != _epoch) return;

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
    if (epoch != _epoch) return;

    // Paint cached SQLite/prefs first so SyncGate can keep ticking during merge.
    await _hydrateFromLocal();
    if (epoch != _epoch) return;
    _markHydrated();

    var syncFinished = false;
    try {
      final result = await _orchestrator
          .run(SyncTrigger.startup)
          .timeout(bootstrapSyncTimeout);
      if (epoch != _epoch) return;
      lastRemoteSyncResult = result;
      syncFinished = true;
      if (result.status == SyncRunStatus.succeeded) {
        _lastRemoteSyncAt = DateTime.now();
      }
    } on TimeoutException {
      lastRemoteSyncResult = const SyncRunResult(status: SyncRunStatus.failed);
    } catch (e) {
      lastRemoteSyncResult = SyncRunResult(
        status: SyncRunStatus.failed,
        error: e,
      );
    }
    if (epoch != _epoch) return;

    // Do not read SQLite here if merge is still running after a timeout —
    // that is what prints "database has been locked".
    if (syncFinished) {
      await _hydrateFromLocal();
    }
    if (epoch != _epoch) return;
    _bootstrapComplete = true;
  }

  void _markHydrated() {
    _sessionHydrated = true;
    _completeLocalReady();
  }

  void _completeLocalReady() {
    final ready = _localReady;
    if (ready != null && !ready.isCompleted) {
      ready.complete();
    }
  }

  /// After SyncGate, offer Retry/Cancel when the first bootstrap hit 404/503.
  ///
  /// Must not run while the gate is visible — a modal would cover the spinner.
  Future<void> retryStartupSyncIfServerDown([
    ServerRequiredRetry? retry,
  ]) async {
    final helper = retry ?? ServerRequiredRetry();
    while (isServerTechnicalWork(lastRemoteSyncResult?.error)) {
      if (!await helper.offerRetry()) return;
      await syncAndHydrate(SyncTrigger.startup);
    }
  }

  Future<void> _hydrateFromLocal() {
    final helper = _helper;
    return Future.wait([
      _safe(() => _goals.load(silent: true)),
      _safe(() => _tasks.load(silent: true)),
      // Orchestrator already merges habits; skip the extra /habits/inprogress call.
      _safe(() => _habits.load(silent: true, syncRemote: false)),
      _safe(() => _settings.load(silent: true)),
      if (helper != null) _safe(() => helper.load(silent: true)),
    ]);
  }

  Future<void> _safe(Future<void> Function() load) async {
    try {
      await load();
    } catch (_) {}
  }
}
