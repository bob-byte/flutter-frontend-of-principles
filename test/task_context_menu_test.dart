import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/theme/task_theme_palette.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/core/utils/date_helpers.dart';
import 'package:principles_app/l10n/app_localizations.dart';
import 'package:principles_app/l10n/task_strings.dart';
import 'package:principles_app/models/task.dart';
import 'package:principles_app/services/task_service.dart';
import 'package:principles_app/viewmodels/tasks_viewmodel.dart';
import 'package:principles_app/widgets/task_context_menu.dart';
import 'package:principles_app/widgets/task_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpTile(WidgetTester tester, {required Task task}) async {
    final palette = TasksUiPalette.of(TasksUiTheme.darkOrange);
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
              final vm = context.read<TasksViewModel>();
              return Scaffold(
                body: TaskTile(
                  key: Key('taskTile-${task.id}'),
                  task: task,
                  palette: palette,
                  themeColor: palette.primary,
                  strings: TaskStrings.en,
                  onTap: () {},
                  onToggle: () {},
                  onLongPress: (anchor) {
                    showTaskContextMenu(
                      context: context,
                      task: task,
                      vm: vm,
                      palette: palette,
                      anchor: anchor,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('long-pressing a task tile opens the task context menu', (
    tester,
  ) async {
    final task = Task(
      id: '1',
      title: 'Buy milk',
      createdAt: DateTime(2026, 1, 1),
      dueDate: DateTime(2026, 1, 1),
    );
    await pumpTile(tester, task: task);
    await tester.longPress(find.byKey(const Key('taskTile-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('taskContextMenu')), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Move to today'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  testWidgets('hides move to today when the task is already due today', (
    tester,
  ) async {
    final task = Task(
      id: '2',
      title: 'Call mom',
      createdAt: DateTime(2026, 1, 1),
      dueDate: dateOnly(DateTime.now()),
    );
    await pumpTile(tester, task: task);
    await tester.longPress(find.byKey(const Key('taskTile-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('taskContextMenu')), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Move to today'), findsNothing);
  });
}
