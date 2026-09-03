import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:principles_app/core/locale/locale_controller.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/models/user.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/settings_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/settings_viewmodel.dart';
import 'package:principles_app/views/settings_view.dart';
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
        ChangeNotifierProvider(
          create: (ctx) => SettingsViewModel(
            settingsService: ctx.read<SettingsService>(),
            localeController: ctx.read<LocaleController>(),
            userService: ctx.read<UserService>(),
          ),
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

  testWidgets('email is not editable', (tester) async {
    await tester.pumpWidget(_buildWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settingsProfileEmailTile')));
    await tester.pumpAndSettle();

    expect(find.text('This field is not editable.'), findsOneWidget);
    expect(find.byKey(const Key('settingsProfileFieldInput')), findsNothing);
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
    expect(find.text('Send an email to us', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Support and Feedback', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Our privacy policy', skipOffstage: false), findsOneWidget);
    expect(find.text('User agreement', skipOffstage: false), findsOneWidget);
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
