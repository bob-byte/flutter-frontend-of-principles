import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/user_goal.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/dialog_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:principles_app/viewmodels/goals_viewmodel.dart';

void main() {
  late _FakeGoalService goals;
  late GoalsViewModel vm;

  setUp(() {
    goals = _FakeGoalService();
    vm = GoalsViewModel(goals, DialogService());
  });

  test('load sorts goals for display', () async {
    goals.items = [
      UserGoal(id: 2, name: 'Zebra', isCompleted: false),
      UserGoal(id: 1, name: 'Alpha', isCompleted: true),
    ];

    await vm.load();

    expect(vm.isLoading, isFalse);
    expect(vm.goals.map((g) => g.name), ['Zebra', 'Alpha']);
  });

  test('addGoal ignores blank names', () async {
    await vm.addGoal('   ');
    expect(goals.saved, isEmpty);
  });

  test('addGoal saves trimmed name and reloads', () async {
    await vm.addGoal('  Read more  ');
    expect(goals.saved.single.name, 'Read more');
    expect(vm.goals, hasLength(1));
  });

  test('deleteGoal removes matching goal from the list', () async {
    final goal = UserGoal(id: 3, name: 'Drop');
    goals.items = [goal];
    await vm.load();
    await vm.deleteGoal(goal);
    expect(goals.deleted, [goal]);
    expect(vm.goals, isEmpty);
  });

  test('clear empties goals', () async {
    goals.items = [UserGoal(id: 1, name: 'A')];
    await vm.load();
    vm.clear();
    expect(vm.goals, isEmpty);
    expect(vm.isLoading, isFalse);
  });
}

class _FakeGoalService extends GoalService {
  _FakeGoalService() : super(AuthService(SecureStore()));

  List<UserGoal> items = [];
  final saved = <UserGoal>[];
  final deleted = <UserGoal>[];

  @override
  Future<List<UserGoal>> getGoals() async => List.of(items);

  @override
  Future<void> saveGoal(UserGoal goal) async {
    saved.add(goal);
    items = [...items, goal];
  }

  @override
  Future<void> deleteGoal(UserGoal goal) async {
    deleted.add(goal);
    items.removeWhere((g) => g.id == goal.id && g.name == goal.name);
  }
}
