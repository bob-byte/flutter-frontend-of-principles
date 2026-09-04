import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/helpers/open_notification_settings.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/services/dialog_service.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DialogService dialogs;

  setUp(() {
    dialogs = DialogService();
    dialogs.hideToast();
    dialogs.isPopupOpen = false;
  });

  tearDown(() {
    dialogs.hideToast();
    dialogs.isPopupOpen = false;
  });

  test('openNotificationSettings invokes the platform channel', () async {
    var opened = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationSettingsChannel, (call) async {
          expect(call.method, 'openNotificationSettings');
          opened = true;
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationSettingsChannel, null);
    });

    expect(await openNotificationSettings(), isTrue);
    expect(opened, isTrue);
  });

  testWidgets('denied-notifications alert offers to open device settings', (
    tester,
  ) async {
    var opened = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationSettingsChannel, (call) async {
          opened = call.method == 'openNotificationSettings';
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationSettingsChannel, null);
    });

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeController(),
        child: MaterialApp(
          navigatorKey: dialogs.navigatorKey,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('home')),
        ),
      ),
    );

    final prompt = dialogs.promptOpenNotificationSettings();
    await tester.pumpAndSettle();

    expect(find.text('Notifications are off'), findsOneWidget);
    expect(
      find.text(
        'To receive reminders, allow notifications in device settings. Open settings now?',
      ),
      findsOneWidget,
    );
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    await prompt;

    expect(opened, isTrue);
  });

  testWidgets('denied-notifications alert No does not open settings', (
    tester,
  ) async {
    var opened = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationSettingsChannel, (call) async {
          opened = true;
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationSettingsChannel, null);
    });

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeController(),
        child: MaterialApp(
          navigatorKey: dialogs.navigatorKey,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('home')),
        ),
      ),
    );

    final prompt = dialogs.promptOpenNotificationSettings();
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    await prompt;

    expect(opened, isFalse);
  });
}
