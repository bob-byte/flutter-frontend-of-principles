import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/sync_queue_service.dart';
import 'package:principles_app/core/sync/sync_service.dart';
import 'package:principles_app/core/sync/sync_snapshot_merge_service.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/services/app_open_tracker_service.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/database_service.dart';
import 'package:principles_app/services/dialog_service.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:principles_app/services/task_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/startup_viewmodel.dart';
import 'package:principles_app/views/startup_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _build() {
  final auth = AuthService(SecureStore());
  final api = ApiClient(SecureStore(), dio: Dio());
  final queue = SyncQueueService(memoryItems: []);
  return LiquidGlassWidgets.wrap(
    brightnessResolver: Theme.maybeBrightnessOf,
    child: MultiProvider(
      providers: [
        Provider.value(value: auth),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        Provider(create: (_) => DialogService()),
        ChangeNotifierProvider(
          create: (_) => StartupViewModel(
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
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const StartupView(showAuthenticationImmediately: true),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows Google and email auth affordances', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('A RenderFlex overflowed')) return;
      previousOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(_build());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Google'), findsOneWidget);
    expect(find.textContaining('Sign up'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
