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
import 'package:principles_app/services/habit_service.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/task_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/habit_progress_viewmodel.dart';
import 'package:principles_app/viewmodels/tasks_viewmodel.dart';
import 'package:principles_app/views/tasks_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentHabits extends HabitProgressViewModel {
  _SilentHabits(super.habitService);

  @override
  Future<void> load({bool silent = false, bool syncRemote = true}) async {}
}

Widget _build() {
  final auth = AuthService(SecureStore());
  return LiquidGlassWidgets.wrap(
    brightnessResolver: Theme.maybeBrightnessOf,
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController()),
        Provider(
          create: (_) =>
              TaskService(apiClient: ApiClient(SecureStore()), taskDb: null),
        ),
        Provider(create: (_) => HabitService(auth)),
        ChangeNotifierProvider(create: (_) => MainShellController()),
        ChangeNotifierProvider(
          create: (ctx) => RoadGuideController(
            userService: UserService(forceLocalOnly: true),
            shell: ctx.read<MainShellController>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => TasksViewModel(
            ctx.read<TaskService>(),
            ctx.read<ThemeController>(),
          ),
        ),
        ChangeNotifierProvider<HabitProgressViewModel>(
          create: (ctx) => _SilentHabits(ctx.read<HabitService>()),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: TasksView(embedded: true)),
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

  testWidgets('renders tasks shell without hanging on empty state', (
    tester,
  ) async {
    await tester.pumpWidget(_build());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(TasksView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
