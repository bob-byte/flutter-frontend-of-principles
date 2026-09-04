import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/core/locale/locale_controller.dart';
import 'package:principles_app/core/storage/local_db.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/local_data_cleaner.dart';
import 'package:principles_app/core/theme/task_theme_palette.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/models/user.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:principles_app/services/settings_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/settings_viewmodel.dart';
import 'package:principles_app/views/app_benefits_view.dart';
import 'package:principles_app/views/settings_view.dart';
import 'package:principles_app/views/startup_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildWidget() {
  return LiquidGlassWidgets.wrap(
    brightnessResolver: Theme.maybeBrightnessOf,
    child: MultiProvider(
      providers: [
        Provider(create: (_) => AuthService(SecureStore())),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => LocaleController()),
        Provider(create: (_) => SettingsService(SecureStore())),
        Provider(create: (_) => UserService(forceLocalOnly: true)),
        Provider(
          create: (ctx) => LocalDataCleaner(
            localDb: LocalDb(),
            userService: ctx.read<UserService>(),
            authService: ctx.read<AuthService>(),
            reminderService: ReminderService(forceLocalOnly: true),
            goalService: GoalService(ctx.read<AuthService>()),
            secureStore: SecureStore(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) {
            final vm = SettingsViewModel(
              settingsService: ctx.read<SettingsService>(),
              localeController: ctx.read<LocaleController>(),
              userService: ctx.read<UserService>(),
              localDataCleaner: ctx.read<LocalDataCleaner>(),
            );
            // Embedded SettingsView skips auto-load; hydrate for widget tests.
            vm.load();
            return vm;
          },
        ),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SettingsView(embedded: true)),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      UserService.prefsKey: jsonEncode(
        User(
          name: 'Ada',
          email: 'ada@example.com',
          mainSlogan: 'Keep going',
          mission: 'Build tools',
          gender: 0,
        ).toJson(),
      ),
    });
  });

  testWidgets('shows profile fields and lets the user edit name', (
    tester,
  ) async {
    await tester.pumpWidget(_buildWidget());
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
    expect(find.text('Keep going'), findsOneWidget);
    expect(find.text('Build tools'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settingsProfileNameTile')));
    await tester.pumpAndSettle();

    expect(find.text('Your Name'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('settingsProfileFieldInput')),
      'Grace',
    );
    await tester.tap(find.byKey(const Key('settingsProfileFieldSave')));
    await tester.pumpAndSettle();

    expect(find.text('Grace'), findsOneWidget);
    expect(find.text('Your name successfully saved'), findsOneWidget);
  });

  testWidgets('lets the user change gender', (tester) async {
    await tester.pumpWidget(_buildWidget());
    await tester.pumpAndSettle();

    expect(find.text('Male'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settingsProfileGenderTile')));
    await tester.pumpAndSettle();

    expect(find.text('Your Gender'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settingsGenderOption_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsGenderSave')));
    await tester.pumpAndSettle();

    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Your gender successfully saved'), findsOneWidget);
  });

  testWidgets('theme setting card changes the app theme', (tester) async {
    await tester.pumpWidget(_buildWidget());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settingsThemeTile')), findsOneWidget);
    expect(find.text('Theme'), findsWidgets);

    await tester.tap(find.byType(PopupMenuButton<TasksUiTheme>));
    await tester.pumpAndSettle();
    expect(find.text('Dark orange'), findsWidgets);

    await tester.tap(find.text('Dark blue').last);
    await tester.pumpAndSettle();

    final theme = tester
        .element(find.byKey(const Key('settingsThemeTile')))
        .read<ThemeController>()
        .uiTheme;
    expect(theme, TasksUiTheme.darkBlue);
  });

  testWidgets('email is not editable', (tester) async {
    await tester.pumpWidget(_buildWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsProfileEmailTile')));
    await tester.pumpAndSettle();

    expect(find.text('This field is not editable.'), findsOneWidget);
    expect(find.byKey(const Key('settingsProfileFieldInput')), findsNothing);
  });

  testWidgets('logout opens startup without showing benefits', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildWidget());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settingsLogoutTile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(StartupView), findsOneWidget);
    expect(find.byType(AppBenefitsView), findsNothing);
  });

  testWidgets('shows support and account actions with the new contact email', (
    tester,
  ) async {
    await tester.pumpWidget(_buildWidget());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('settingsTelegramTile')),
      200,
    );
    expect(
      find.text('Join our Telegram channel', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Rate us', skipOffstage: false), findsOneWidget);
    expect(find.text('Share app', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Send an email to us', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Support and Feedback', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Our privacy policy', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('User agreement', skipOffstage: false), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Change password'), 200);
    expect(find.text('Change password', skipOffstage: false), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settingsDeleteAccountTile')),
      200,
    );
    expect(find.text('Delete account'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settingsDeleteAccountTile')));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsOneWidget);
    expect(find.text("Once you delete, it's gone for good."), findsOneWidget);

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account?'), findsNothing);
    expect(find.byKey(const Key('settingsDeleteAccountTile')), findsOneWidget);
  });
}
