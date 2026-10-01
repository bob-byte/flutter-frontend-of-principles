import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../config/app_config.dart';
import '../network/network_service.dart';
import 'sync_authentication_exception.dart';
import 'sync_reachability_service.dart';
import 'sync_run_result.dart';
import 'sync_service.dart';
import 'sync_trigger.dart';

class SyncOrchestrator {
  SyncOrchestrator({
    required NetworkService network,
    required SettingsService settings,
    required SyncReachabilityService reachability,
    required SyncService syncService,
    required AuthService authService,
  }) : _network = network,
       _settings = settings,
       _reachability = reachability,
       _syncService = syncService,
       _authService = authService;

  final NetworkService _network;
  final SettingsService _settings;
  final SyncReachabilityService _reachability;
  final SyncService _syncService;
  final AuthService _authService;
  Future<SyncRunResult>? _inFlight;

  Future<SyncRunResult> run(SyncTrigger trigger) async {
    final existing = _inFlight;
    if (existing != null) {
      // A silent push must not reuse a pull that may have started before the
      // remote delete/edit landed — callers retry after skippedAlreadyRunning.
      if (trigger == SyncTrigger.remotePush) {
        await existing;
        return const SyncRunResult(status: SyncRunStatus.skippedAlreadyRunning);
      }
      return existing;
    }

    final inFlight = _runBody(trigger);
    _inFlight = inFlight;
    try {
      return await inFlight;
    } finally {
      if (identical(_inFlight, inFlight)) {
        _inFlight = null;
      }
    }
  }

  Future<SyncRunResult> _runBody(SyncTrigger _) async {
    try {
      if (AppConfig.useLocalData) {
        return _result(SyncRunStatus.skippedLocalOnly);
      }

      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        return _result(SyncRunStatus.skippedNoAuth);
      }

      // Post-splash ensureLoaded may race NetworkService.start() (defaults
      // to offline until the first connectivity check completes).
      await _network.ensureStarted();
      if (!_network.isConnected) {
        return _result(SyncRunStatus.skippedNoInternet);
      }

      final reachable = await _reachability.canReachBackend();
      if (!reachable) {
        await _settings.setLastFailedSyncAt(DateTime.now().toUtc());
        return _result(SyncRunStatus.skippedBackendUnavailable);
      }

      // Prefer /sync/changes whenever a cursor exists (cold start included).
      // No cursor → full bootstrap. SyncService falls back to bootstrap if the
      // server sets RequiresFullBootstrap or /changes is missing.
      // SyncGate covers the shell only for full bootstrap or since ≥ 20 days
      // (see sync_gate_policy.dart).
      final since = await _settings.getLastSuccessfulSyncAt();

      final serverTime = await _syncService.sync(since: since);
      final cursor = serverTime ?? DateTime.now().toUtc();
      await _settings.setLastSuccessfulSyncAt(cursor);
      await _settings.setLastFailedSyncAt(null);
      return SyncRunResult(
        status: SyncRunStatus.succeeded,
        lastSuccessfulSyncAt: cursor,
      );
    } on SyncAuthenticationException catch (e) {
      await _settings.setLastFailedSyncAt(DateTime.now().toUtc());
      return _result(SyncRunStatus.failedAuthentication, e);
    } catch (e) {
      await _settings.setLastFailedSyncAt(DateTime.now().toUtc());
      return _result(SyncRunStatus.failed, e);
    }
  }

  SyncRunResult _result(SyncRunStatus status, [Object? error]) {
    return SyncRunResult(status: status, error: error);
  }
}
