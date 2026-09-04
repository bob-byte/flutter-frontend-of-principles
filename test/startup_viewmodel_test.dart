import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/sync_queue_service.dart';
import 'package:principles_app/core/sync/sync_service.dart';
import 'package:principles_app/core/sync/sync_snapshot_merge_service.dart';
import 'package:principles_app/services/app_open_tracker_service.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/database_service.dart';
import 'package:principles_app/services/dialog_service.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:principles_app/services/task_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/startup_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuth auth;
  late StartupViewModel vm;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    auth = _FakeAuth();
    final api = ApiClient(SecureStore(), dio: Dio());
    final queue = SyncQueueService(memoryItems: []);
    vm = StartupViewModel(
      authService: auth,
      syncService: SyncService(
        queue: queue,
        authService: auth,
        apiClient: api,
        mergeService: SyncSnapshotMergeService(
          queue: queue,
          databaseService: DatabaseService(),
          userService: UserService(forceLocalOnly: true),
          reminderService: ReminderService(forceLocalOnly: true),
          taskService: TaskService(apiClient: api),
        ),
        databaseService: DatabaseService(),
        handlers: const [],
      ),
      reminderService: ReminderService(forceLocalOnly: true),
      dialogService: DialogService(),
      appOpenTracker: AppOpenTrackerService(),
    );
  });

  test('routes logged-in users to helper', () async {
    auth.hasSession = true;
    expect(await vm.initialize(), StartupNextRoute.helper);
  });

  test('routes first-time guests to app benefits', () async {
    auth.hasSession = false;
    expect(await vm.initialize(), StartupNextRoute.appBenefits);
  });

  test('acknowledgeAppBenefitsShown forces next initialize to login', () async {
    auth.hasSession = false;
    await vm.initialize();
    vm.acknowledgeAppBenefitsShown();
    expect(await vm.initialize(), StartupNextRoute.login);
  });
}

class _FakeAuth extends AuthService {
  _FakeAuth() : super(SecureStore());

  bool hasSession = false;

  @override
  Future<bool> hasLocalSession() async => hasSession;

  @override
  Future<void> ensureGuestSession() async {}
}
