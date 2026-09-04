import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/task_priority.dart';
import 'package:principles_app/viewmodels/tasks_viewmodel.dart';

void main() {
  Habit habit({required int id, required String name, DateTime? reminderTime}) {
    return Habit(id: id, name: name, reminderTime: reminderTime);
  }

  List<Habit> call({
    TasksListMode listMode = TasksListMode.today,
    required List<Habit> habits,
    TaskStatusFilter statusFilter = TaskStatusFilter.all,
    TaskPriority? priorityFilter,
    String? themeFilter,
    bool Function(Habit)? isCompleted,
  }) {
    return habitsVisibleOnTasksTab(
      listMode: listMode,
      habits: habits,
      statusFilter: statusFilter,
      priorityFilter: priorityFilter,
      themeFilter: themeFilter,
      isCompleted: isCompleted ?? (_) => false,
    );
  }

  test('inbox shows uncompleted habits', () {
    final habits = [
      habit(id: 1, name: 'Done habit'),
      habit(id: 2, name: 'Open habit'),
    ];
    final done = {1};
    final result = call(
      listMode: TasksListMode.inbox,
      habits: habits,
      isCompleted: (h) => done.contains(h.id),
    );
    expect(result.map((h) => h.name), ['Open habit']);
  });

  test('completed mode shows only completed habits', () {
    final habits = [
      habit(id: 1, name: 'Done habit'),
      habit(id: 2, name: 'Undone habit'),
    ];
    final done = {1};
    final result = call(
      listMode: TasksListMode.completed,
      habits: habits,
      isCompleted: (h) => done.contains(h.id),
    );
    expect(result.map((h) => h.name), ['Done habit']);
  });

  test('shows habits on today, tomorrow and selected day', () {
    final habits = [habit(id: 1, name: 'Train')];
    expect(
      call(listMode: TasksListMode.today, habits: habits).map((h) => h.name),
      ['Train'],
    );
    expect(
      call(listMode: TasksListMode.tomorrow, habits: habits).map((h) => h.name),
      ['Train'],
    );
    expect(
      call(listMode: TasksListMode.day, habits: habits).map((h) => h.name),
      ['Train'],
    );
  });

  test('status filter: active hides completed habits', () {
    final habits = [habit(id: 1, name: 'Read'), habit(id: 2, name: 'Train')];
    final done = {1};

    final active = call(
      habits: habits,
      statusFilter: TaskStatusFilter.active,
      isCompleted: (h) => done.contains(h.id),
    );
    expect(active.map((h) => h.name), ['Train']);
  });

  test('status filter: done shows only completed habits', () {
    final habits = [habit(id: 1, name: 'Read'), habit(id: 2, name: 'Train')];
    final done = {1};

    final completed = call(
      habits: habits,
      statusFilter: TaskStatusFilter.done,
      isCompleted: (h) => done.contains(h.id),
    );
    expect(completed.map((h) => h.name), ['Read']);
  });

  test('priority filter hides habits section', () {
    final habits = [habit(id: 1, name: 'Train')];
    expect(call(habits: habits, priorityFilter: TaskPriority.high), isEmpty);
  });

  test('category/theme filter hides habits section', () {
    final habits = [habit(id: 1, name: 'Train')];
    expect(call(habits: habits, themeFilter: 'Work'), isEmpty);
  });

  test('incomplete habits sorted before completed, then by time', () {
    final habits = [
      habit(id: 1, name: 'Read'),
      habit(id: 2, name: 'Train', reminderTime: DateTime(2026, 1, 1, 7)),
      habit(id: 3, name: 'Walk', reminderTime: DateTime(2026, 1, 1, 8)),
    ];
    final done = {1};

    final all = call(habits: habits, isCompleted: (h) => done.contains(h.id));
    expect(all.map((h) => h.name), ['Train', 'Walk', 'Read']);
  });
}
