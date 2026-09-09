import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/network_service.dart';
import 'package:principles_app/core/network/server_required_retry.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/sync_authentication_exception.dart';
import 'package:principles_app/core/sync/sync_orchestrator.dart';
import 'package:principles_app/core/sync/sync_queue_service.dart';
import 'package:principles_app/core/sync/sync_reachability_service.dart';
import 'package:principles_app/core/sync/sync_run_result.dart';
import 'package:principles_app/core/sync/sync_service.dart';
import 'package:principles_app/core/sync/sync_snapshot_merge_service.dart';
import 'package:principles_app/core/sync/sync_trigger.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/database_service.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:principles_app/services/settings_service.dart';
import 'package:principles_app/services/task_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Auth auth;
  late SettingsService settings;
  late _FakeReachability reachability;
  late _FakeSyncService syncService;
  late NetworkService network;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    AppConfig.debugUseLocalDataOverride = null;
    auth = _Auth('token');
    settings = SettingsService(SecureStore());
    reachability = _FakeReachability();
    syncService = _FakeSyncService();
    network = NetworkService(
      initialConnected: true,
      checkConnectivity: () async => [],
      connectivityChanges: const Stream.empty(),
    );
  });

  tearDown(() {
    AppConfig.debugUseLocalDataOverride = null;
  });

  SyncOrchestrator orchestrator() => SyncOrchestrator(
    network: network,
    settings: settings,
    reachability: reachability,
    syncService: syncService,
    authService: auth,
  );

  test('skips when DATA_SOURCE is local-only', () async {
    AppConfig.debugUseLocalDataOverride = true;
    final result = await orchestrator().run(SyncTrigger.resume);
    expect(result.status, SyncRunStatus.skippedLocalOnly);
    expect(syncService.calls, 0);
  });

  test('skips when there is no auth token', () async {
    auth.token = null;
    final result = await orchestrator().run(SyncTrigger.resume);
    expect(result.status, SyncRunStatus.skippedNoAuth);
    expect(syncService.calls, 0);
  });

  test('skips when offline', () async {
    network.isConnected = false;
    final result = await orchestrator().run(SyncTrigger.resume);
    expect(result.status, SyncRunStatus.skippedNoInternet);
    expect(syncService.calls, 0);
  });

  test('skips when backend unreachable and stamps failed sync', () async {
    reachability.reachable = false;
    final result = await orchestrator().run(SyncTrigger.resume);
    expect(result.status, SyncRunStatus.skippedBackendUnavailable);
    expect(await settings.getLastFailedSyncAt(), isNotNull);
  });

  test('succeeds and stamps last successful sync', () async {
    final result = await orchestrator().run(SyncTrigger.startup);
    expect(result.status, SyncRunStatus.succeeded);
    expect(syncService.calls, 1);
    expect(syncService.lastSince, isNull);
    expect(await settings.getLastSuccessfulSyncAt(), isNotNull);
    expect(await settings.getLastFailedSyncAt(), isNull);
  });

  test('startup passes stored since for incremental sync', () async {
    final stamp = DateTime.utc(2026, 9, 1, 10);
    await settings.setLastSuccessfulSyncAt(stamp);
    final result = await orchestrator().run(SyncTrigger.startup);
    expect(result.status, SyncRunStatus.succeeded);
    expect(syncService.lastSince, stamp);
  });

  test('resume passes stored since for incremental sync', () async {
    final stamp = DateTime.utc(2026, 9, 1, 10);
    await settings.setLastSuccessfulSyncAt(stamp);
    final result = await orchestrator().run(SyncTrigger.resume);
    expect(result.status, SyncRunStatus.succeeded);
    expect(syncService.lastSince, stamp);
    expect(
      await settings.getLastSuccessfulSyncAt(),
      DateTime.utc(2026, 9, 9, 12),
    );
  });

  test('coalesces concurrent runs into one sync', () async {
    syncService.delay = const Duration(milliseconds: 80);
    final a = orchestrator();
    final first = a.run(SyncTrigger.resume);
    final second = a.run(SyncTrigger.startup);
    final results = await Future.wait([first, second]);
    expect(results[0].status, SyncRunStatus.succeeded);
    expect(results[1].status, SyncRunStatus.succeeded);
    expect(syncService.calls, 1);
  });

  test('maps SyncAuthenticationException to failedAuthentication', () async {
    syncService.error = SyncAuthenticationException();
    final result = await orchestrator().run(SyncTrigger.resume);
    expect(result.status, SyncRunStatus.failedAuthentication);
    expect(await settings.getLastFailedSyncAt(), isNotNull);
  });

  test('maps generic errors to failed', () async {
    syncService.error = StateError('boom');
    final result = await orchestrator().run(SyncTrigger.resume);
    expect(result.status, SyncRunStatus.failed);
    expect(result.error, isA<StateError>());
  });

  test('ping 404 becomes a failed technical-work result', () async {
    reachability.error = const ServerTechnicalWorkException(statusCode: 404);
    final result = await orchestrator().run(SyncTrigger.startup);
    expect(result.status, SyncRunStatus.failed);
    expect(isServerTechnicalWork(result.error), isTrue);
    expect(syncService.calls, 0);
  });
}

class _Auth extends AuthService {
  _Auth(this.token) : super(SecureStore());

  String? token;

  @override
  Future<String?> getToken() async => token;
}

class _FakeReachability extends SyncReachabilityService {
  _FakeReachability()
    : super(
        apiClient: ApiClient(SecureStore(), dio: Dio()),
        authService: AuthService(SecureStore()),
      );

  bool reachable = true;
  Object? error;

  @override
  Future<bool> canReachBackend() async {
    final thrown = error;
    if (thrown != null) throw thrown;
    return reachable;
  }
}

class _FakeSyncService extends SyncService {
  _FakeSyncService()
    : super(
        queue: SyncQueueService(memoryItems: []),
        authService: AuthService(SecureStore()),
        apiClient: ApiClient(SecureStore(), dio: Dio()),
        mergeService: SyncSnapshotMergeService(
          queue: SyncQueueService(memoryItems: []),
          databaseService: DatabaseService(),
          userService: UserService(forceLocalOnly: true),
          reminderService: ReminderService(forceLocalOnly: true),
          taskService: TaskService(
            apiClient: ApiClient(SecureStore(), dio: Dio()),
          ),
        ),
        databaseService: DatabaseService(),
        handlers: const [],
      );

  int calls = 0;
  Duration delay = Duration.zero;
  Object? error;
  DateTime? lastSince;

  @override
  Future<DateTime?> sync({DateTime? since}) async {
    calls++;
    lastSince = since;
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    final err = error;
    if (err != null) throw err;
    return DateTime.utc(2026, 9, 9, 12);
  }
}
