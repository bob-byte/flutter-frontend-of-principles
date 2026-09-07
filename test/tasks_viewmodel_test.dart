import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/theme/theme_controller.dart';
import 'package:principles_app/core/utils/date_helpers.dart';
import 'package:principles_app/models/task.dart';
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
  }) {
    return Task(
      id: id,
      title: title,
      isDone: isDone,
      createdAt: DateTime(2026, 1, 1),
      dueDate: dueDate,
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
    expect(vm.filteredTasks.map((t) => t.title), ['Done']);
  });
}
