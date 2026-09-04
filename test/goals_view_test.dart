import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/core/road_guide/main_shell_controller.dart';
import 'package:principles_app/core/road_guide/road_guide_controller.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/user_goal.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/dialog_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:principles_app/services/habit_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/goals_viewmodel.dart';
import 'package:principles_app/viewmodels/habit_progress_viewmodel.dart';
import 'package:principles_app/views/goals_view.dart';
import 'package:principles_app/views/widgets/add_edit_goal_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _goalsCacheKey = 'user_goals_cache';

Widget _buildWidget({List<Habit> habits = const []}) {
  final dialogService = DialogService();
  dialogService.registerDialogBuilder(DialogType.addEditGoal, (context, data) {
    return AddEditGoalDialogWidget(existingGoal: data as UserGoal?);
  });
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

    expect(find.text('No goals yet. Add one above.'), findsOneWidget);
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
    expect(find.byKey(const Key('goalDialogFieldInput')), findsOneWidget);
    expect(find.byKey(const Key('goalDialogComplete')), findsOneWidget);
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

    await tester.tap(find.byKey(const Key('goalDialogComplete')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byKey(const Key('appToast')), findsOneWidget);
    expect(find.text('Goal marked as completed'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
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
  });
}
