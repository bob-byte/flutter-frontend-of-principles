import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../core/locale/locale_controller.dart';
import '../core/storage/local_db.dart';
import '../core/storage/secure_store.dart';
import '../core/sync/sync_service.dart';
import '../core/theme/theme_controller.dart';
import '../services/ai_chat_service.dart';
import '../services/ai_recommendation_service.dart';
import '../services/auth_service.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../services/progress_service.dart';
import '../services/reminder_service.dart';
import '../services/settings_service.dart';
import '../viewmodels/edit_habit_viewmodel.dart';
import '../viewmodels/goals_viewmodel.dart';
import '../viewmodels/helper_viewmodel.dart';
import '../viewmodels/habit_detail_viewmodel.dart';
import '../viewmodels/login_viewmodel.dart';
import '../viewmodels/progress_viewmodel.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../viewmodels/startup_viewmodel.dart';
import '../views/edit_habit_view.dart';
import '../views/goals_view.dart';
import '../views/helper_view.dart';
import '../views/habit_detail_view.dart';
import '../views/login_view.dart';
import '../views/progress_view.dart';
import '../views/settings_view.dart';
import '../views/startup_view.dart';
import 'router.dart';

class PrinciplesApp extends StatelessWidget {
  const PrinciplesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => SecureStore()),
        Provider(create: (_) => LocalDb()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => LocaleController()),
        Provider(create: (ctx) => SettingsService(ctx.read<SecureStore>())),
        Provider(create: (ctx) => AuthService(ctx.read<SecureStore>())),
        Provider(create: (_) => GoalService()),
        Provider(create: (_) => HabitService()),
        Provider(create: (_) => ProgressService()),
        Provider(create: (_) => ReminderService()),
        Provider(create: (_) => AiChatService()),
        Provider(create: (_) => AiRecommendationService()),
        ProxyProvider2<LocalDb, AuthService, SyncService>(
          update: (context, db, auth, previous) => SyncService(db: db, authService: auth),
        ),
        ChangeNotifierProvider(
          create: (ctx) => StartupViewModel(
            authService: ctx.read<AuthService>(),
            syncService: ctx.read<SyncService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => LoginViewModel(ctx.read<AuthService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => HelperViewModel(ctx.read<AiChatService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => EditHabitViewModel(
            habitService: ctx.read<HabitService>(),
            recommendationService: ctx.read<AiRecommendationService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => GoalsViewModel(ctx.read<GoalService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ProgressViewModel(ctx.read<ProgressService>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => HabitDetailViewModel(
            habitService: ctx.read<HabitService>(),
            progressService: ctx.read<ProgressService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => SettingsViewModel(
            settingsService: ctx.read<SettingsService>(),
            themeController: ctx.read<ThemeController>(),
            localeController: ctx.read<LocaleController>(),
          ),
        ),
      ],
      child: Consumer2<ThemeController, LocaleController>(
        builder: (context, themeController, localeController, child) {
          return MaterialApp(
            onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
            theme: themeController.lightTheme,
            darkTheme: themeController.darkTheme,
            themeMode: themeController.themeMode,
            locale: localeController.localeOverride,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('uk'),
            ],
            onGenerateRoute: AppRouter.generateRoute,
            initialRoute: StartupView.routeName,
            routes: {
              StartupView.routeName: (_) => const StartupView(),
              LoginView.routeName: (_) => const LoginView(),
              HelperView.routeName: (_) => const HelperView(),
              HabitDetailView.routeName: (_) => const HabitDetailView(),
              EditHabitView.routeName: (_) => const EditHabitView(),
              GoalsView.routeName: (_) => const GoalsView(),
              ProgressView.routeName: (_) => const ProgressView(),
              SettingsView.routeName: (_) => const SettingsView(),
            },
          );
        },
      ),
    );
  }
}
