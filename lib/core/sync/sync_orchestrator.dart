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
      return existing;
    }

    final inFlight = _runBody();
    _inFlight = inFlight;
    try {
      return await inFlight;
    } finally {
      if (identical(_inFlight, inFlight)) {
        _inFlight = null;
      }
    }
  }

  Future<SyncRunResult> _runBody() async {
    try {
      if (AppConfig.useLocalData) {
        return _result(SyncRunStatus.skippedLocalOnly);
      }

      final token = await _authService.getToken();
      if (token == null || token.isEmpty) {
        return _result(SyncRunStatus.skippedNoAuth);
      }

      if (!_network.isConnected) {
        return _result(SyncRunStatus.skippedNoInternet);
      }

      final reachable = await _reachability.canReachBackend();
      if (!reachable) {
        await _settings.setLastFailedSyncAt(DateTime.now().toUtc());
        return _result(SyncRunStatus.skippedBackendUnavailable);
      }

      await _syncService.sync();
      await _settings.setLastSuccessfulSyncAt(DateTime.now().toUtc());
      await _settings.setLastFailedSyncAt(null);
      return _result(SyncRunStatus.succeeded);
    } on SyncAuthenticationException catch (e) {
      await _settings.setLastFailedSyncAt(DateTime.now().toUtc());
      return _result(SyncRunStatus.failedAuthentication, e);
    } catch (e) {
      await _settings.setLastFailedSyncAt(DateTime.now().toUtc());
      return _result(SyncRunStatus.failed, e);
    }
  }

  SyncRunResult _result(SyncRunStatus status, [Object? error]) {
    return SyncRunResult(
      status: status,
      error: error,
    );
  }
}
