import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/road_guide/main_shell_controller.dart';
import 'package:principles_app/core/road_guide/road_guide_controller.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/services/ai_recommendation_service.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/database_service.dart';
import 'package:principles_app/services/dialog_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:principles_app/services/habit_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/goals_viewmodel.dart';
import 'package:principles_app/viewmodels/habit_progress_viewmodel.dart';
import 'package:principles_app/views/goals_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _goalsCacheKey = 'user_goals_cache';

Widget _buildWidget({List<Habit> habits = const []}) {
  final dialogService = DialogService();
  final habitVm = HabitProgressViewModel(
    HabitService(AuthService(SecureStore())),
  )..habits = List<Habit>.from(habits);

  return LiquidGlassWidgets.wrap(
    brightnessResolver: Theme.maybeBrightnessOf,
    child: MultiProvider(
      providers: [
        Provider<DialogService>.value(value: dialogService),
        Provider(create: (_) => AuthService(SecureStore())),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        Provider(create: (ctx) => GoalService(ctx.read<AuthService>())),
        Provider(create: (_) => DatabaseService()),
        Provider(create: (ctx) => HabitService(ctx.read<AuthService>())),
        Provider(
          create: (_) => AiRecommendationService(ApiClient(SecureStore())),
        ),
        Provider(create: (_) => UserService(forceLocalOnly: true)),
        ChangeNotifierProvider(
          create: (ctx) => GoalsViewModel(
            ctx.read<GoalService>(),
            ctx.read<DialogService>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => MainShellController()),
        ChangeNotifierProvider(
          create: (ctx) => RoadGuideController(
            userService: UserService(forceLocalOnly: true),
            shell: ctx.read<MainShellController>(),
          ),
        ),
        ChangeNotifierProvider<HabitProgressViewModel>.value(value: habitVm),
      ],
      child: MaterialApp(
        navigatorKey: dialogService.navigatorKey,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: GoalsView(embedded: true)),
      ),
    ),
  );
}

Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  await tester.pump();
  final context = tester.element(find.byType(GoalsView));
  await context.read<GoalsViewModel>().load();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    DialogService().isPopupOpen = false;
    DialogService().hideToast();
  });

  tearDown(() {
    DialogService().hideToast();
  });

  testWidgets('shows empty-state copy when there are no goals', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_buildWidget());
    await _pumpUntilLoaded(tester);

    expect(find.text('No goals yet. Tap + to add one.'), findsOneWidget);
  });

  testWidgets('tapping a goal opens the edit dialog', (tester) async {
    SharedPreferences.setMockInitialValues({
      _goalsCacheKey: [
        jsonEncode({
          'id': 1,
          'name': 'Be a reader',
          'lastModified': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
      ],
    });
    await tester.pumpWidget(_buildWidget());
    await _pumpUntilLoaded(tester);

    expect(find.text('Be a reader'), findsOneWidget);

    await tester.tap(find.byKey(const Key('goalTile-1-Be a reader')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Edit goal'), findsOneWidget);
    expect(find.byKey(const Key('goalNameField')), findsOneWidget);
    expect(find.byKey(const Key('goalNotesField')), findsOneWidget);
    expect(find.byKey(const Key('goalCompleteButton')), findsOneWidget);
    expect(find.byKey(const Key('goalCreateHabit')), findsOneWidget);
    expect(find.byKey(const Key('goalGenerateHabits')), findsOneWidget);
    expect(find.text('Be a reader'), findsWidgets);
  });

  testWidgets('edit dialog complete icon marks the goal completed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      _goalsCacheKey: [
        jsonEncode({
          'id': 1,
          'name': 'Be a reader',
          'lastModified': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
      ],
    });
    await tester.pumpWidget(_buildWidget());
    await _pumpUntilLoaded(tester);

    await tester.tap(find.byKey(const Key('goalTile-1-Be a reader')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.byKey(const Key('goalCompleteButton')));
    await tester.tap(find.byKey(const Key('goalCompleteButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byKey(const Key('appToast')), findsOneWidget);
    expect(find.text('Goal marked as completed'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Completed'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    DialogService().hideToast();
  });

  testWidgets('long-pressing a goal opens the context menu', (tester) async {
    SharedPreferences.setMockInitialValues({
      _goalsCacheKey: [
        jsonEncode({
          'id': 1,
          'name': 'Be a reader',
          'lastModified': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
      ],
    });
    await tester.pumpWidget(_buildWidget());
    await _pumpUntilLoaded(tester);

    await tester.longPress(find.byKey(const Key('goalTile-1-Be a reader')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('goalContextMenu')), findsOneWidget);
    expect(find.text('Mark as completed'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Edit goal'), findsNothing);
  });

  testWidgets('marking a goal completed moves it to the completed section', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      _goalsCacheKey: [
        jsonEncode({
          'id': 1,
          'name': 'Be a reader',
          'lastModified': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
      ],
    });
    await tester.pumpWidget(_buildWidget());
    await _pumpUntilLoaded(tester);

    await tester.longPress(find.byKey(const Key('goalTile-1-Be a reader')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Mark as completed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Mark as completed'), findsNothing);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    DialogService().hideToast();
  });

  testWidgets('lists habits under the goal they belong to', (tester) async {
    SharedPreferences.setMockInitialValues({
      _goalsCacheKey: [
        jsonEncode({
          'id': 1,
          'name': 'Be a reader',
          'lastModified': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
      ],
    });
    await tester.pumpWidget(
      _buildWidget(
        habits: [
          Habit(
            id: 10,
            name: 'Read 10 pages',
            targetGoal: 'Be a reader',
            targetGoalId: 1,
          ),
          Habit(id: 11, name: 'Train'),
        ],
      ),
    );
    await _pumpUntilLoaded(tester);

    expect(find.text('Be a reader'), findsOneWidget);
    expect(find.text('Read 10 pages'), findsOneWidget);
    expect(find.text('1 habit'), findsOneWidget);
    expect(find.text('Train'), findsOneWidget);
    expect(find.text('*Goal not defined'), findsOneWidget);

    await tester.tap(find.byKey(const Key('goalTile-1-Be a reader')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Read 10 pages'), findsWidgets);
    expect(find.text('No habits for this goal yet.'), findsNothing);
  });

  testWidgets('status filter hides completed goals and unassigned habits', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      _goalsCacheKey: [
        jsonEncode({
          'id': 1,
          'name': 'Active goal',
          'lastModified': DateTime.utc(2026, 1, 1).toIso8601String(),
        }),
        jsonEncode({
          'id': 2,
          'name': 'Done goal',
          'isCompleted': true,
          'lastModified': DateTime.utc(2026, 1, 2).toIso8601String(),
        }),
      ],
    });
    await tester.pumpWidget(
      _buildWidget(habits: [Habit(id: 11, name: 'Train')]),
    );
    await _pumpUntilLoaded(tester);

    expect(find.text('Active goal'), findsOneWidget);
    expect(find.text('Done goal'), findsOneWidget);
    expect(find.text('Train'), findsOneWidget);

    await tester.tap(find.byKey(const Key('goalFiltersButton')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Active'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Active goal'), findsOneWidget);
    expect(find.text('Done goal'), findsNothing);
    expect(find.text('Train'), findsOneWidget);

    await tester.tap(find.text('Completed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Active goal'), findsNothing);
    expect(find.text('Done goal'), findsOneWidget);
    expect(find.text('Train'), findsNothing);
    expect(find.text('*Goal not defined'), findsNothing);
  });
}
