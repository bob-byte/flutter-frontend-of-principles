import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/services/task_service.dart';
import 'package:principles_app/viewmodels/tasks_viewmodel.dart';
import 'package:principles_app/widgets/tasks_list_menu_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpMenu(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TasksViewModel(
          TaskService(apiClient: ApiClient(SecureStore()), taskDb: null),
          ThemeController(),
        ),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () => showTasksListMenuSheet(context),
                  child: const Text('Open menu'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open menu'));
    await tester.pumpAndSettle();
  }

  testWidgets('list menu does not overflow on a short desktop window', (
    tester,
  ) async {
    await pumpMenu(tester, size: const Size(800, 420));

    expect(find.text('Show tasks'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Daily reminder'),
      80,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Daily reminder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('list menu sheet is expandable', (tester) async {
    await pumpMenu(tester, size: const Size(400, 800));

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('Show tasks'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('list menu items remain tappable after opening', (tester) async {
    await pumpMenu(tester, size: const Size(400, 900));

    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();

    expect(find.text('Show tasks'), findsNothing);
  });
}
