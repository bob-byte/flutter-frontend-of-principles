import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/day_change_notifier.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/core/utils/date_helpers.dart';
import 'package:principles_app/models/task.dart';
import 'package:principles_app/services/completion_feedback.dart';
import 'package:principles_app/services/task_service.dart';
import 'package:principles_app/viewmodels/tasks_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  Task task({
    required String id,
    required String title,
    bool isDone = false,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Task(
      id: id,
      title: title,
      isDone: isDone,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      dueDate: dueDate,
      completedAt: completedAt,
    );
  }

  TasksViewModel vmWith(List<Task> tasks) {
    final vm = TasksViewModel(
      TaskService(apiClient: ApiClient(SecureStore()), taskDb: null),
      ThemeController(),
    );
    vm.tasks.addAll(tasks);
    return vm;
  }

  test('day change notifier rebuilds today/tomorrow filters', () {
    var now = DateTime(2026, 9, 8, 10);
    final dayChange = DayChangeNotifier(
      clock: () => now,
      observeLifecycle: false,
      scheduleTimer: false,
    );
    addTearDown(dayChange.dispose);

    final vm = TasksViewModel(
      TaskService(apiClient: ApiClient(SecureStore()), taskDb: null),
      ThemeController(),
      dayChange: dayChange,
    );
    addTearDown(vm.dispose);

    var notifications = 0;
    vm.addListener(() => notifications++);

    now = DateTime(2026, 9, 9, 0, 1);
    expect(dayChange.checkForDayChange(), isTrue);
    expect(notifications, 1);
  });

  test('inbox shows all uncompleted tasks regardless of due date', () {
    final vm = vmWith([
      task(id: '1', title: 'No date'),
      task(id: '2', title: 'Dated', dueDate: DateTime(2026, 9, 4)),
      task(id: '3', title: 'Done no date', isDone: true),
      task(
        id: '4',
        title: 'Done dated',
        isDone: true,
        dueDate: DateTime(2026, 9, 4),
      ),
    ]);

    vm.setListModeInbox();

    expect(
      vm.filteredTasks.map((t) => t.title),
      unorderedEquals(['No date', 'Dated']),
    );
  });

  test('tomorrow shows only tasks due tomorrow', () {
    final today = dateOnly(DateTime.now());
    final tomorrow = tomorrowDate(now: today);
    final vm = vmWith([
      task(id: '1', title: 'Today', dueDate: today),
      task(id: '2', title: 'Tomorrow', dueDate: tomorrow),
      task(id: '3', title: 'No date'),
      task(id: '4', title: 'Done tomorrow', isDone: true, dueDate: tomorrow),
    ]);

    vm.setListModeTomorrow();

    // Default status filter is active — completed tasks are hidden.
    expect(vm.filteredTasks.map((t) => t.title), ['Tomorrow']);

    vm.setStatusFilter(TaskStatusFilter.all);
    expect(vm.filteredTasks.map((t) => t.title), ['Tomorrow', 'Done tomorrow']);
  });

  test(
    'default status filter hides completed tasks and clear resets to active',
    () {
      final today = dateOnly(DateTime.now());
      final vm = vmWith([
        task(id: '1', title: 'Open', dueDate: today),
        task(id: '2', title: 'Done', isDone: true, dueDate: today),
      ]);

      expect(vm.statusFilter, TaskStatusFilter.active);
      expect(vm.hasActiveFilters, isFalse);
      expect(vm.filteredTasks.map((t) => t.title), ['Open']);

      vm.setStatusFilter(TaskStatusFilter.all);
      expect(vm.hasActiveFilters, isTrue);
      expect(vm.filteredTasks.map((t) => t.title), ['Open', 'Done']);

      vm.clearFilters();
      expect(vm.statusFilter, TaskStatusFilter.active);
      expect(vm.hasActiveFilters, isFalse);
    },
  );

  test('completed list mode shows done tasks despite active status chip', () {
    final vm = vmWith([
      task(id: '1', title: 'Open'),
      task(id: '2', title: 'Done', isDone: true),
    ]);

    vm.setListModeCompleted();
    expect(vm.statusFilter, TaskStatusFilter.active);
    expect(vm.showsStatusFilter, isFalse);
    expect(vm.filteredTasks.map((t) => t.title), ['Done']);
  });

  test('status filter is hidden on inbox and completed list modes', () {
    final vm = vmWith([task(id: '1', title: 'Open')]);
    expect(vm.showsStatusFilter, isTrue);

    vm.setStatusFilter(TaskStatusFilter.done);
    expect(vm.hasActiveFilters, isTrue);

    vm.setListModeInbox();
    expect(vm.showsStatusFilter, isFalse);
    expect(vm.hasActiveFilters, isFalse);

    vm.setListModeCompleted();
    expect(vm.showsStatusFilter, isFalse);
    expect(vm.hasActiveFilters, isFalse);

    vm.setListModeToday();
    expect(vm.showsStatusFilter, isTrue);
    expect(vm.hasActiveFilters, isTrue);
    vm.dispose();
  });

  test('held completed tasks stay on active until celebration ends', () async {
    final today = dateOnly(DateTime.now());
    final vm = vmWith([
      task(
        id: '1',
        title: 'Open',
        dueDate: today,
        createdAt: DateTime(2026, 1, 2),
      ),
      task(
        id: '2',
        title: 'Just done',
        isDone: true,
        dueDate: today,
        createdAt: DateTime(2026, 1, 1),
      ),
    ]);

    expect(vm.filteredTasks.map((t) => t.title), ['Open']);

    vm.debugHoldCompletedTask('2');
    expect(vm.filteredTasks.map((t) => t.title), ['Open', 'Just done']);

    await Future<void>.delayed(
      kCompletionCelebrationDuration + const Duration(milliseconds: 40),
    );
    expect(vm.filteredTasks.map((t) => t.title), ['Open']);
    vm.dispose();
  });

  test('held completed tasks keep their place among active items', () {
    final today = dateOnly(DateTime.now());
    final vm = vmWith([
      task(
        id: '1',
        title: 'First',
        dueDate: today,
        createdAt: DateTime(2026, 1, 3),
      ),
      task(
        id: '2',
        title: 'Middle',
        isDone: true,
        dueDate: today,
        createdAt: DateTime(2026, 1, 2),
      ),
      task(
        id: '3',
        title: 'Last',
        dueDate: today,
        createdAt: DateTime(2026, 1, 1),
      ),
    ]);

    expect(vm.filteredTasks.map((t) => t.title), ['First', 'Last']);
    vm.debugHoldCompletedTask('2');
    expect(vm.filteredTasks.map((t) => t.title), ['First', 'Middle', 'Last']);
    vm.dispose();
  });

  test('held completed overdue tasks stay on today during celebration', () {
    final today = dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final vm = vmWith([
      task(
        id: '1',
        title: 'Overdue done',
        isDone: true,
        dueDate: yesterday,
        completedAt: today.add(const Duration(hours: 10)),
      ),
    ]);

    // Default Active filter still hides finished overdue after the hold.
    expect(vm.filteredTasks, isEmpty);
    vm.debugHoldCompletedTask('1');
    expect(vm.filteredTasks.map((t) => t.title), ['Overdue done']);
    vm.dispose();
  });

  test('overdue tasks completed today appear under Today Done filter', () {
    final today = dateOnly(DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));
    final vm = vmWith([
      task(
        id: '1',
        title: 'Finished today',
        isDone: true,
        dueDate: yesterday,
        completedAt: today.add(const Duration(hours: 9)),
      ),
      task(
        id: '2',
        title: 'Finished earlier',
        isDone: true,
        dueDate: yesterday,
        completedAt: lastWeek,
      ),
      task(id: '3', title: 'Still open overdue', dueDate: yesterday),
    ]);

    vm.setStatusFilter(TaskStatusFilter.done);

    expect(vm.filteredTasks.map((t) => t.title), ['Finished today']);
    expect(vm.todayCompletedCount, 1);
    expect(
      vm.todayTasks.map((t) => t.title),
      unorderedEquals(['Finished today', 'Still open overdue']),
    );
    vm.dispose();
  });

  test(
    'load replaces list after fetch so concurrent upsert cannot duplicate',
    () async {
      final gate = Completer<void>();
      final service = _GatedTaskService(gate);
      await service.saveTask(
        Task(id: '2', title: 'From db', createdAt: DateTime(2026, 1, 1)),
        isNew: false,
      );

      final vm = TasksViewModel(service, ThemeController());
      addTearDown(vm.dispose);

      final loading = vm.load(silent: true);
      await Future<void>.delayed(Duration.zero);
      await vm.upsertTask(
        Task(id: '2', title: 'Upserted', createdAt: DateTime(2026, 1, 1)),
      );
      gate.complete();
      await loading;

      expect(vm.tasks.where((t) => t.id == '2'), hasLength(1));
    },
  );

  test('upsertTask collapses matching server and client ids', () async {
    final vm = vmWith([
      Task(
        id: 'L1',
        title: 'Local',
        createdAt: DateTime(2026, 1, 1),
        serverId: 2,
      ),
      Task(
        id: '2',
        title: 'Server-shaped',
        createdAt: DateTime(2026, 1, 1),
        serverId: 2,
      ),
    ]);
    addTearDown(vm.dispose);

    await vm.upsertTask(
      Task(
        id: 'L1',
        title: 'Kept',
        createdAt: DateTime(2026, 1, 1),
        serverId: 2,
      ),
    );

    expect(vm.tasks, hasLength(1));
    expect(vm.tasks.single.title, 'Kept');
  });

  test(
    'uncompleting one task in Completed keeps the other completed rows',
    () async {
      final today = dateOnly(DateTime.now());
      final service = TaskService(
        apiClient: ApiClient(SecureStore()),
        taskDb: null,
      );
      await service.saveTask(
        task(
          id: '1',
          title: 'Keep done',
          isDone: true,
          dueDate: today,
          completedAt: today.add(const Duration(hours: 8)),
        ),
        isNew: false,
      );
      await service.saveTask(
        task(
          id: '2',
          title: 'Reopen me',
          isDone: true,
          dueDate: today,
          completedAt: today.add(const Duration(hours: 9)),
        ),
        isNew: false,
      );

      final vm = TasksViewModel(service, ThemeController());
      addTearDown(vm.dispose);
      await vm.load();
      vm.setListModeCompleted();
      // Allow background _ensureCompletedLoaded to finish.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        vm.filteredTasks.map((t) => t.title),
        unorderedEquals(['Keep done', 'Reopen me']),
      );

      await vm.toggleTask('2');

      expect(vm.filteredTasks.map((t) => t.title), ['Keep done']);
      expect(vm.tasks.any((t) => t.id == '2' && !t.isDone), isTrue);
    },
  );
}

class _GatedTaskService extends TaskService {
  _GatedTaskService(this._gate)
    : super(apiClient: ApiClient(SecureStore()), taskDb: null);

  final Completer<void> _gate;

  @override
  Future<List<Task>> getTasks({bool? isDone}) async {
    await _gate.future;
    return super.getTasks(isDone: isDone);
  }

  @override
  Future<List<Task>> getSessionTasks({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required DateTime today,
  }) async {
    await _gate.future;
    return super.getSessionTasks(
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      today: today,
    );
  }
}
