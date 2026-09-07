import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/input/android_hardware_text_input.dart';
import '../core/launch_data_loader.dart';
import '../core/locale/locale_controller.dart';
import '../core/network/api_client.dart';
import '../core/network/network_service.dart';
import '../core/road_guide/main_shell_controller.dart';
import '../core/road_guide/road_guide_controller.dart';
import '../core/storage/local_db.dart';
import '../core/storage/secure_store.dart';
import '../core/storage/task_db.dart';
import '../core/sync/handlers/goal_sync_handler.dart';
import '../core/sync/handlers/habit_sync_handler.dart';
import '../core/sync/handlers/progress_sync_handler.dart';
import '../core/sync/handlers/reminder_sync_handler.dart';
import '../core/sync/handlers/task_sync_handler.dart';
import '../core/sync/handlers/user_sync_handler.dart';
import '../core/sync/local_data_cleaner.dart';
import '../core/sync/local_remote_executor.dart';
import '../core/sync/sync_orchestrator.dart';
import '../core/sync/sync_queue_service.dart';
import '../core/sync/sync_reachability_service.dart';
import '../core/sync/sync_service.dart';
import '../core/sync/sync_snapshot_merge_service.dart';
import '../core/sync/sync_trigger.dart';
import '../core/theme/theme_controller.dart';
import '../services/ai_chat_service.dart';
import '../services/ai_recommendation_service.dart';
import '../services/app_open_tracker_service.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/dialog_service.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../services/progress_service.dart';
import '../services/reminder_service.dart';
import '../services/settings_service.dart';
import '../services/task_service.dart';
import '../services/user_service.dart';
import '../viewmodels/edit_habit_viewmodel.dart';
import '../viewmodels/edit_task_viewmodel.dart';
import '../viewmodels/goals_viewmodel.dart';
import '../viewmodels/app_benefits_viewmodel.dart';
import '../viewmodels/helper_viewmodel.dart';
import '../viewmodels/habit_detail_viewmodel.dart';
import '../viewmodels/login_viewmodel.dart';
import '../viewmodels/signup_viewmodel.dart';
import '../viewmodels/forget_password_viewmodel.dart';
import '../viewmodels/habit_progress_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../viewmodels/startup_viewmodel.dart';
import '../viewmodels/tasks_viewmodel.dart';
import '../models/habit.dart';
import '../views/goals_view.dart';
import '../views/app_benefits_view.dart';
import '../views/helper_view.dart';
import '../views/edit_habit_view.dart';
import '../views/habit_detail_view.dart';
import '../views/login_view.dart';
import '../views/signup_view.dart';
import '../views/forget_password_view.dart';
import '../views/main_view.dart';
import '../views/habit_progress_view.dart';
import '../views/settings_view.dart';
import '../views/startup_view.dart';
import '../views/tasks_view.dart';
import '../views/main_shell.dart';
import '../views/video_splash_view.dart';
import '../widgets/app_update_alert.dart';
import 'router.dart';

/// Survives [MaterialApp] rebuilds when [ThemeController] finishes restore.
final GlobalKey _videoSplashKey = GlobalKey();

class PrinciplesApp extends StatelessWidget {
  const PrinciplesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => SecureStore()),
        Provider(create: (_) => LocalDb()),
        Provider(create: (ctx) => SettingsService(ctx.read<SecureStore>())),
        ChangeNotifierProvider(
          create: (ctx) {
            final controller = ThemeController(
              settingsService: ctx.read<SettingsService>(),
            );
            controller.restore();
            return controller;
          },
        ),
        ChangeNotifierProvider(create: (_) => LocaleController()),
        Provider(create: (_) => DialogService()),
        Provider(create: (ctx) => ApiClient(ctx.read<SecureStore>())),
        Provider(create: (ctx) => AuthService(ctx.read<SecureStore>())),
        Provider(
          create: (ctx) => SyncQueueService(localDb: ctx.read<LocalDb>()),
        ),
        ChangeNotifierProvider(create: (_) => NetworkService()),
        Provider(
          create: (ctx) => LocalRemoteExecutor(
            queue: ctx.read<SyncQueueService>(),
            network: ctx.read<NetworkService>(),
          ),
        ),
        Provider(
          create: (ctx) => DatabaseService(localDb: ctx.read<LocalDb>()),
        ),
        Provider(
          create: (ctx) => UserService(
            apiClient: ctx.read<ApiClient>(),
            localDb: ctx.read<LocalDb>(),
            executor: ctx.read<LocalRemoteExecutor>(),
          ),
        ),
        Provider(
          create: (ctx) => GoalService(
            ctx.read<AuthService>(),
            localDb: ctx.read<LocalDb>(),
            executor: ctx.read<LocalRemoteExecutor>(),
            queue: ctx.read<SyncQueueService>(),
          ),
        ),
        Provider(
          create: (ctx) => HabitService(
            ctx.read<AuthService>(),
            dbService: ctx.read<DatabaseService>(),
            network: ctx.read<NetworkService>(),
            queue: ctx.read<SyncQueueService>(),
            executor: ctx.read<LocalRemoteExecutor>(),
          ),
        ),
        Provider(create: (_) => ProgressService()),
        Provider(
          create: (ctx) => ReminderService(
            apiClient: ctx.read<ApiClient>(),
            localDb: ctx.read<LocalDb>(),
            executor: ctx.read<LocalRemoteExecutor>(),
          ),
        ),
        Provider(create: (ctx) => AiChatService(ctx.read<ApiClient>())),
        Provider(
          create: (ctx) => AiRecommendationService(ctx.read<ApiClient>()),
        ),
        Provider(create: (_) => kIsWeb ? null : TaskDb()),
        Provider(
          create: (ctx) => TaskService(
            apiClient: ctx.read<ApiClient>(),
            taskDb: ctx.read<TaskDb?>(),
            localDb: ctx.read<LocalDb>(),
            executor: ctx.read<LocalRemoteExecutor>(),
          ),
        ),
        Provider(
          create: (ctx) {
            final queue = ctx.read<SyncQueueService>();
            final apiClient = ctx.read<ApiClient>();
            final goalService = ctx.read<GoalService>();
            final habitService = ctx.read<HabitService>();
            final reminderService = ctx.read<ReminderService>();
            final taskService = ctx.read<TaskService>();
            return SyncService(
              queue: queue,
              authService: ctx.read<AuthService>(),
              apiClient: apiClient,
              mergeService: SyncSnapshotMergeService(
                queue: queue,
                databaseService: ctx.read<DatabaseService>(),
                userService: ctx.read<UserService>(),
                reminderService: reminderService,
                taskService: taskService,
              ),
              databaseService: ctx.read<DatabaseService>(),
              handlers: [
                UserSyncHandler(apiClient),
                GoalSyncHandler(apiClient, goalService: goalService),
                HabitSyncHandler(habitService),
                ProgressSyncHandler(habitService),
                ReminderSyncHandler(
                  apiClient,
                  reminderService: reminderService,
                ),
                TaskSyncHandler(apiClient, taskService: taskService),
              ],
            );
          },
        ),
        Provider(
          create: (ctx) => LocalDataCleaner(
            localDb: ctx.read<LocalDb>(),
            userService: ctx.read<UserService>(),
            authService: ctx.read<AuthService>(),
            reminderService: ctx.read<ReminderService>(),
            goalService: ctx.read<GoalService>(),
            secureStore: ctx.read<SecureStore>(),
          ),
        ),
        Provider(
          create: (ctx) {
            final network = ctx.read<NetworkService>();
            final orchestrator = SyncOrchestrator(
              network: network,
              settings: ctx.read<SettingsService>(),
              reachability: SyncReachabilityService(
                apiClient: ctx.read<ApiClient>(),
                authService: ctx.read<AuthService>(),
              ),
              syncService: ctx.read<SyncService>(),
              authService: ctx.read<AuthService>(),
            );
            final cleaner = ctx.read<LocalDataCleaner>();
            network.onConnectivityRestored = () =>
                orchestrator.run(SyncTrigger.connectivityRestored);
            network.onAuthenticationFailure = cleaner.clearLocalData;
            network.start();
            return orchestrator;
          },
        ),
        Provider(create: (_) => AppOpenTrackerService()),
        ChangeNotifierProvider(
          create: (ctx) => StartupViewModel(
            authService: ctx.read<AuthService>(),
            syncService: ctx.read<SyncService>(),
            reminderService: ctx.read<ReminderService>(),
            dialogService: ctx.read<DialogService>(),
            appOpenTracker: ctx.read<AppOpenTrackerService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => LoginViewModel(
            ctx.read<AuthService>(),
            syncService: ctx.read<SyncService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => SignupViewModel(
            ctx.read<AuthService>(),
            syncService: ctx.read<SyncService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => AppBenefitsViewModel(ctx.read<AuthService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ForgetPasswordViewModel(ctx.read<AuthService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => HelperViewModel(ctx.read<AiChatService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => EditHabitViewModel(
            ctx.read<HabitService>(),
            ctx.read<ReminderService>(),
            ctx.read<GoalService>(),
            ctx.read<AiRecommendationService>(),
            ctx.read<UserService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => GoalsViewModel(
            ctx.read<GoalService>(),
            ctx.read<DialogService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => HabitProgressViewModel(
            ctx.read<HabitService>(),
            appOpenTracker: ctx.read<AppOpenTrackerService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              HabitDetailViewModel(habitService: ctx.read<HabitService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => SettingsViewModel(
            settingsService: ctx.read<SettingsService>(),
            localeController: ctx.read<LocaleController>(),
            userService: ctx.read<UserService>(),
            localDataCleaner: ctx.read<LocalDataCleaner>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => MainShellController()),
        ChangeNotifierProvider(
          create: (ctx) => RoadGuideController(
            userService: ctx.read<UserService>(),
            shell: ctx.read<MainShellController>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => TasksViewModel(
            ctx.read<TaskService>(),
            ctx.read<ThemeController>(),
            reminderService: ctx.read<ReminderService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => EditTaskViewModel(
            ctx.read<TaskService>(),
            reminderService: ctx.read<ReminderService>(),
          ),
        ),
        Provider(
          create: (ctx) => LaunchDataLoader(
            startup: ctx.read<StartupViewModel>(),
            orchestrator: ctx.read<SyncOrchestrator>(),
            goals: ctx.read<GoalsViewModel>(),
            tasks: ctx.read<TasksViewModel>(),
            habits: ctx.read<HabitProgressViewModel>(),
            settings: ctx.read<SettingsViewModel>(),
          ),
        ),
      ],
      child: Consumer2<ThemeController, LocaleController>(
        builder: (context, themeController, localeController, child) {
          return LiquidGlassWidgets.wrap(
            brightnessResolver: Theme.maybeBrightnessOf,
            adaptiveQuality: true,
            child: MaterialApp(
              navigatorKey: context.read<DialogService>().navigatorKey,
              builder: (context, child) => AndroidHardwareTextInput(
                child: VideoSplashOverlay(
                  key: _videoSplashKey,
                  child: AppUpdateAlert(
                    navigatorKey: context.read<DialogService>().navigatorKey,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context)!.appTitle,
              theme: themeController.lightTheme,
              darkTheme: themeController.darkTheme,
              themeMode: themeController.themeMode,
              locale:
                  localeController.localeOverride ?? const Locale('uk', 'UA'),
              localeListResolutionCallback: (deviceLocales, supported) {
                if (localeController.localeOverride != null) {
                  return localeController.localeOverride;
                }
                for (final device in deviceLocales ?? const <Locale>[]) {
                  if (device.languageCode == 'uk') {
                    return const Locale('uk', 'UA');
                  }
                  for (final s in supported) {
                    if (s.languageCode == device.languageCode) return s;
                  }
                }
                return const Locale('uk', 'UA');
              },
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('uk', 'UA'),
                Locale('uk'),
                Locale('en'),
              ],
              onGenerateRoute: AppRouter.generateRoute,
              initialRoute: StartupView.routeName,
              routes: {
                StartupView.routeName: (ctx) => StartupView(
                  showAuthenticationImmediately:
                      ModalRoute.of(ctx)?.settings.arguments == true,
                ),
                LoginView.routeName: (_) => const LoginView(),
                SignupView.routeName: (_) => const SignupView(),
                AppBenefitsView.routeName: (_) => const AppBenefitsView(),
                ForgetPasswordView.routeName: (ctx) {
                  final email =
                      ModalRoute.of(ctx)?.settings.arguments as String?;
                  return ForgetPasswordView(initialEmail: email);
                },
                HelperView.routeName: (_) => const MainShell(),
                MainView.routeName: (_) => const MainView(),
                HabitDetailView.routeName: (_) => const HabitDetailView(),
                EditHabitView.routeName: (ctx) {
                  final habit =
                      ModalRoute.of(ctx)?.settings.arguments as Habit?;
                  return EditHabitView(habit: habit);
                },
                GoalsView.routeName: (_) => const GoalsView(),
                HabitProgressView.routeName: (_) => const HabitProgressView(),
                SettingsView.routeName: (_) => const SettingsView(),
                TasksView.routeName: (_) => const TasksView(),
              },
            ),
          );
        },
      ),
    );
  }
}
