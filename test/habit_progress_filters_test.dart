import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/habit_record.dart';
import 'package:principles_app/viewmodels/habit_progress_viewmodel.dart';

void main() {
  Habit habit({
    required int id,
    String name = 'Walk',
    String targetGoal = '',
    int? targetGoalId,
  }) {
    return Habit(
      id: id,
      name: name,
      targetGoal: targetGoal,
      targetGoalId: targetGoalId,
    );
  }

  bool matches({
    required Habit item,
    HabitDayStatusFilter dayStatus = HabitDayStatusFilter.notDone,
    HabitDueFilter due = HabitDueFilter.due,
    String? goalKey,
    HabitStatus status = HabitStatus.none,
    bool appliesOnSelectedDay = true,
    bool keepVisible = false,
  }) {
    return habitMatchesProgressFilters(
      habit: item,
      dayStatus: dayStatus,
      due: due,
      goalKey: goalKey,
      status: status,
      appliesOnSelectedDay: appliesOnSelectedDay,
      keepVisible: keepVisible,
    );
  }

  test('default not-done hides completed and skipped', () {
    final open = habit(id: 1);
    expect(matches(item: open), isTrue);
    expect(matches(item: open, status: HabitStatus.completed), isFalse);
    expect(matches(item: open, status: HabitStatus.skipped), isFalse);
  });

  test('not-done keeps a just-completed row while held', () {
    expect(
      matches(
        item: habit(id: 1),
        status: HabitStatus.completed,
        keepVisible: true,
      ),
      isTrue,
    );
  });

  test('all day-status includes every progress mark', () {
    final item = habit(id: 1);
    expect(matches(item: item, dayStatus: HabitDayStatusFilter.all), isTrue);
    expect(
      matches(
        item: item,
        dayStatus: HabitDayStatusFilter.all,
        status: HabitStatus.completed,
      ),
      isTrue,
    );
    expect(
      matches(
        item: item,
        dayStatus: HabitDayStatusFilter.all,
        status: HabitStatus.skipped,
      ),
      isTrue,
    );
  });

  test('done day-status selects completed habits', () {
    final item = habit(id: 1);
    expect(
      matches(
        item: item,
        dayStatus: HabitDayStatusFilter.done,
        status: HabitStatus.completed,
      ),
      isTrue,
    );
    expect(matches(item: item, dayStatus: HabitDayStatusFilter.done), isFalse);
  });

  test(
    'due filter scopes habits by whether they apply on the selected day',
    () {
      final item = habit(id: 1);
      expect(matches(item: item, appliesOnSelectedDay: false), isFalse);
      expect(matches(item: item, appliesOnSelectedDay: true), isTrue);
      expect(
        matches(
          item: item,
          due: HabitDueFilter.notDue,
          appliesOnSelectedDay: false,
        ),
        isTrue,
      );
      expect(
        matches(
          item: item,
          due: HabitDueFilter.notDue,
          appliesOnSelectedDay: true,
        ),
        isFalse,
      );
      expect(
        matches(
          item: item,
          due: HabitDueFilter.all,
          appliesOnSelectedDay: false,
        ),
        isTrue,
      );
    },
  );

  test('goal key matches grouping keys including unassigned', () {
    final assigned = habit(id: 1, targetGoal: 'Career', targetGoalId: 9);
    final unassigned = habit(id: 2);

    expect(habitGoalGroupKey(unassigned), kUndefinedHabitGoalKey);
    expect(habitGoalGroupKey(assigned), 'id:9');
    expect(matches(item: assigned, goalKey: 'id:9'), isTrue);
    expect(matches(item: assigned, goalKey: kUndefinedHabitGoalKey), isFalse);
    expect(matches(item: unassigned, goalKey: kUndefinedHabitGoalKey), isTrue);
  });
}
