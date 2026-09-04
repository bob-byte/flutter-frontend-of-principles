import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/user_goal.dart';
import 'package:principles_app/viewmodels/habit_progress_viewmodel.dart';

void main() {
  Habit habit({
    required int id,
    required String name,
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

  test('groups habits by goal and puts undefined goals first', () {
    final groups = groupHabitsByGoal([
      habit(
        id: 1,
        name: 'Read 10 pages',
        targetGoal: 'Be a reader',
        targetGoalId: 2,
      ),
      habit(id: 2, name: 'Train'),
      habit(
        id: 3,
        name: 'Carry a book',
        targetGoal: 'Be a reader',
        targetGoalId: 2,
      ),
      habit(id: 4, name: 'Network', targetGoal: 'Collaborate'),
    ]);

    expect(groups, hasLength(3));
    expect(groups[0].isUndefined, isTrue);
    expect(groups[0].habits.map((h) => h.name), ['Train']);
    expect(groups[1].goalName, 'Be a reader');
    expect(groups[1].habits.map((h) => h.name), [
      'Carry a book',
      'Read 10 pages',
    ]);
    expect(groups[2].goalName, 'Collaborate');
    expect(groups[2].habits.map((h) => h.name), ['Network']);
  });

  test('habitsForGoal matches by id or name', () {
    final goal = UserGoal(id: 2, name: 'Be a reader');
    final matched = habitsForGoal([
      habit(
        id: 1,
        name: 'Read 10 pages',
        targetGoal: 'Be a reader',
        targetGoalId: 2,
      ),
      habit(id: 2, name: 'Train'),
      habit(id: 3, name: 'Carry a book', targetGoal: 'Be a reader'),
      habit(id: 4, name: 'Network', targetGoal: 'Collaborate'),
    ], goal);

    expect(matched.map((h) => h.name), ['Carry a book', 'Read 10 pages']);
  });

  test('habitsUnassignedToGoals excludes habits linked to a goal', () {
    final goals = [
      UserGoal(id: 2, name: 'Be a reader'),
      UserGoal(id: 3, name: 'Collaborate'),
    ];
    final unassigned = habitsUnassignedToGoals([
      habit(id: 1, name: 'Read 10 pages', targetGoalId: 2),
      habit(id: 2, name: 'Train'),
      habit(id: 4, name: 'Network', targetGoal: 'Collaborate'),
    ], goals);

    expect(unassigned.map((h) => h.name), ['Train']);
  });
}
