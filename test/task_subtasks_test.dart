import 'package:dio/dio.dart';
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
import 'package:principles_app/models/task_item_dto.dart';
import 'package:principles_app/models/task_repeat_config.dart';
import 'package:principles_app/models/task_subtask.dart';
import 'package:principles_app/services/task_service.dart';
import 'package:principles_app/viewmodels/edit_task_viewmodel.dart';
import 'package:principles_app/viewmodels/tasks_viewmodel.dart';
import 'package:principles_app/widgets/task_tile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_local_db.dart';

TaskService _offlineService() {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(requestOptions: options, message: 'offline'),
        );
      },
    ),
  );
  return TaskService(
    apiClient: ApiClient(SecureStore(), dio: dio),
    taskDb: null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('TaskSubtask', () {
    test('round-trips JSON including PascalCase keys', () {
      const item = TaskSubtask(
        id: 's1',
        title: 'Milk',
        isDone: true,
        sortOrder: 2,
      );
      expect(TaskSubtask.fromJson(item.toJson()), item);

      final decoded = TaskSubtask.fromJson({
        'Id': 's2',
        'Name': 'Eggs',
        'IsCompleted': false,
        'SortOrder': 1,
      });
      expect(decoded.id, 's2');
      expect(decoded.title, 'Eggs');
      expect(decoded.isDone, isFalse);
      expect(decoded.sortOrder, 1);
    });

    test('sanitize drops blank titles and reindexes', () {
      final cleaned = TaskSubtask.sanitize([
        const TaskSubtask(id: 'a', title: '  Milk  ', sortOrder: 9),
        const TaskSubtask(id: 'b', title: '   ', sortOrder: 1),
        const TaskSubtask(id: 'c', title: 'Eggs', isDone: true, sortOrder: 0),
      ]);
      expect(cleaned, [
        const TaskSubtask(id: 'a', title: 'Milk', sortOrder: 0),
        const TaskSubtask(id: 'c', title: 'Eggs', isDone: true, sortOrder: 1),
      ]);
    });

    test('templateForNextOccurrence copies unchecked with new ids', () {
      final next = TaskSubtask.templateForNextOccurrence([
        const TaskSubtask(id: 'a', title: 'Milk', isDone: true, sortOrder: 0),
        const TaskSubtask(id: 'b', title: 'Eggs', sortOrder: 1),
      ]);
      expect(next, hasLength(2));
      expect(next.map((e) => e.title), ['Milk', 'Eggs']);
      expect(next.every((e) => !e.isDone), isTrue);
      expect(next.every((item) => item.id != 'a' && item.id != 'b'), isTrue);
    });
  });

  group('TaskItemDto subtasks', () {
    test('omitted key stays null so merge can keep local rows', () {
      final dto = TaskItemDto.fromJson({'id': 7, 'name': 'Inbox'});
      expect(dto.subtasks, isNull);
    });

    test('round-trips nested checklist', () {
      final dto = TaskItemDto.fromJson({
        'id': 8,
        'name': 'Shop',
        'subtasks': [
          {'id': 's1', 'name': 'Milk', 'isCompleted': true, 'sortOrder': 0},
          {'id': 's2', 'name': 'Bread', 'isCompleted': false, 'sortOrder': 1},
        ],
      });
      expect(dto.subtasks, hasLength(2));
      expect(dto.subtasks!.first.isDone, isTrue);

      final task = dto.toTask();
      expect(task.subtasks.map((e) => e.title), ['Milk', 'Bread']);

      final encoded = TaskItemDto.fromTask(task).toJson();
      expect(encoded['subtasks'], hasLength(2));
      expect((encoded['subtasks'] as List).first['name'], 'Milk');
    });
  });

  group('TaskService subtasks', () {
    late TaskService service;

    setUp(() {
      service = _offlineService();
    });

    test('persists checklist locally', () async {
      await service.saveTask(
        Task(
          id: 't1',
          title: 'Shop',
          createdAt: DateTime.utc(2026, 1, 1),
          subtasks: const [
            TaskSubtask(id: 's1', title: 'Milk', isDone: true, sortOrder: 0),
          ],
        ),
        isNew: false,
      );

      final loaded = await service.getTask('t1');
      expect(loaded!.subtasks, hasLength(1));
      expect(loaded.subtasks.single.title, 'Milk');
      expect(loaded.subtasks.single.isDone, isTrue);
    });

    test('merge keeps local subtasks when DTO omits them', () async {
      await service.saveTask(
        Task(
          id: '7',
          title: 'Inbox',
          createdAt: DateTime.utc(2026, 1, 1),
          subtasks: const [
            TaskSubtask(id: 's1', title: 'Milk', isDone: true, sortOrder: 0),
          ],
        ),
        isNew: false,
      );

      await service.mergeRemoteTask(
        const TaskItemDto(id: 7, name: 'Inbox', isCompleted: false),
      );

      final merged = await service.getTask('7');
      expect(merged!.subtasks.single.title, 'Milk');
      expect(merged.subtasks.single.isDone, isTrue);
    });

    test('merge replaces subtasks when DTO includes them', () async {
      await service.saveTask(
        Task(
          id: '7',
          title: 'Inbox',
          createdAt: DateTime.utc(2026, 1, 1),
          subtasks: const [
            TaskSubtask(id: 's1', title: 'Milk', isDone: true, sortOrder: 0),
          ],
        ),
        isNew: false,
      );

      await service.mergeRemoteTask(
        const TaskItemDto(
          id: 7,
          name: 'Inbox',
          subtasks: [TaskSubtask(id: 's2', title: 'Bread', sortOrder: 0)],
        ),
      );

      final merged = await service.getTask('7');
      expect(merged!.subtasks.single.title, 'Bread');
      expect(merged.subtasks.single.isDone, isFalse);
    });
  });

  group('SQLite task_subtasks', () {
    test('stores children in a separate table', () async {
      final harness = await createTestDatabaseService();
      addTearDown(
        () => disposeTestDatabase(localDb: harness.localDb, path: harness.path),
      );

      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(requestOptions: options, message: 'offline'),
            );
          },
        ),
      );
      final service = TaskService(
        apiClient: ApiClient(SecureStore(), dio: dio),
        localDb: harness.localDb,
      );

      await service.saveTask(
        Task(
          id: 'sqlite-1',
          title: 'Pack',
          createdAt: DateTime.utc(2026, 1, 1),
          subtasks: const [
            TaskSubtask(id: 's1', title: 'Passport', sortOrder: 0),
            TaskSubtask(id: 's2', title: 'Charger', isDone: true, sortOrder: 1),
          ],
        ),
        isNew: false,
      );

      final db = await harness.localDb.database;
      final rows = await db.query(
        'task_subtasks',
        where: 'taskId = ?',
        whereArgs: ['sqlite-1'],
        orderBy: 'sortOrder ASC',
      );
      expect(rows, hasLength(2));
      expect(rows.first['title'], 'Passport');
      expect(rows.last['isDone'], 1);

      final loaded = await service.getTask('sqlite-1');
      expect(loaded!.subtasks.map((e) => e.title), ['Passport', 'Charger']);

      await service.deleteTask('sqlite-1');
      final leftover = await db.query(
        'task_subtasks',
        where: 'taskId = ?',
        whereArgs: ['sqlite-1'],
      );
      expect(leftover, isEmpty);
    });
  });

  group('EditTaskViewModel subtasks', () {
    test('save drops blank rows', () async {
      final vm = EditTaskViewModel(_offlineService());
      vm.prepareCreate();
      vm.setTitle('Shop');
      vm.addSubtask();
      vm.setSubtaskTitle(vm.subtasks.first.id, '  ');
      vm.addSubtask();
      vm.setSubtaskTitle(vm.subtasks.last.id, 'Milk');

      final saved = await vm.save();
      expect(saved, isNotNull);
      expect(saved!.subtasks, hasLength(1));
      expect(saved.subtasks.single.title, 'Milk');
    });
  });

  group('TasksViewModel subtasks', () {
    test('toggleSubtask flips an item without completing the parent', () async {
      final service = _offlineService();
      final vm = TasksViewModel(service, ThemeController());
      vm.tasks.add(
        Task(
          id: '1',
          title: 'Shop',
          createdAt: DateTime(2026, 1, 1),
          subtasks: const [
            TaskSubtask(id: 'a', title: 'Milk', sortOrder: 0),
            TaskSubtask(id: 'b', title: 'Eggs', isDone: true, sortOrder: 1),
          ],
        ),
      );

      await vm.toggleSubtask('1', 'a');

      expect(vm.tasks.single.isDone, isFalse);
      expect(vm.tasks.single.completedSubtaskCount, 2);
      expect(vm.tasks.single.subtasks.first.isDone, isTrue);
    });

    test('completing a repeating task copies unchecked subtasks', () async {
      final service = _offlineService();
      final vm = TasksViewModel(service, ThemeController());
      await service.saveTask(
        Task(
          id: 'r1',
          title: 'Daily pack',
          createdAt: DateTime(2026, 1, 1),
          dueDate: dateOnly(DateTime.now()),
          repeat: const TaskRepeatConfig(preset: TaskRepeatPreset.daily),
          subtasks: const [
            TaskSubtask(id: 'a', title: 'Passport', isDone: true, sortOrder: 0),
          ],
        ),
        isNew: false,
      );
      await vm.load();
      await vm.toggleTask('r1');

      final open = vm.tasks.where((task) => !task.isDone).toList();
      expect(open, isNotEmpty);
      expect(open.first.subtasks.single.title, 'Passport');
      expect(open.first.subtasks.single.isDone, isFalse);
      expect(open.first.subtasks.single.id, isNot('a'));
    });
  });

  testWidgets('task tile shows checklist progress and toggles a sub-task', (
    tester,
  ) async {
    final palette = TasksUiPalette.of(TasksUiTheme.darkOrange);
    final toggled = <String>[];
    final task = Task(
      id: '1',
      title: 'Shop',
      createdAt: DateTime(2026, 1, 1),
      subtasks: const [
        TaskSubtask(id: 'a', title: 'Milk', isDone: true, sortOrder: 0),
        TaskSubtask(id: 'b', title: 'Eggs', sortOrder: 1),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TasksViewModel(_offlineService(), ThemeController()),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TaskTile(
              task: task,
              palette: palette,
              themeColor: palette.primary,
              strings: TaskStrings.en,
              onTap: () {},
              onToggle: () {},
              onToggleSubtask: toggled.add,
            ),
          ),
        ),
      ),
    );

    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    await tester.tap(find.byKey(const Key('taskSubtaskToggle-b')));
    expect(toggled, ['b']);
  });
}
