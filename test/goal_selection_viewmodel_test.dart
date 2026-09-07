import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/user_goal.dart';
import 'package:principles_app/services/ai_recommendation_service.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/dialog_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:principles_app/services/habit_service.dart';
import 'package:principles_app/services/reminder_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/edit_habit_viewmodel.dart';
import 'package:principles_app/viewmodels/goal_selection_viewmodel.dart';
import 'package:principles_app/viewmodels/goals_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeGoalService goals;
  late GoalsViewModel goalsVm;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    goals = _FakeGoalService();
    goalsVm = GoalsViewModel(goals, DialogService());
  });

  test('deleteGoal removes the goal from GoalsViewModel', () async {
    final keep = UserGoal(id: 1, name: 'Keep');
    final drop = UserGoal(id: 2, name: 'Drop');
    goals.items = [keep, drop];
    await goalsVm.load();

    final selectionVm = GoalSelectionViewModel(
      goals,
      currentTargetGoal: '',
      goalsViewModel: goalsVm,
    );
    await selectionVm.loadGoals();
    await selectionVm.deleteGoal(drop);

    expect(goals.deleted, [drop]);
    expect(goalsVm.goals.map((g) => g.name), ['Keep']);
    expect(selectionVm.goals.map((g) => g.name), ['Keep']);
  });

  test('deleteGoal clears the matching habit target goal', () async {
    final drop = UserGoal(id: 4, name: 'Fitness');
    goals.items = [drop];
    await goalsVm.load();

    final auth = AuthService(SecureStore());
    final editVm = EditHabitViewModel(
      HabitService(auth),
      ReminderService(forceLocalOnly: true),
      goals,
      AiRecommendationService(ApiClient(SecureStore())),
      UserService(forceLocalOnly: true),
    )..init(Habit(name: 'Run', targetGoal: 'Fitness', targetGoalId: 4));

    final selectionVm = GoalSelectionViewModel(
      goals,
      currentTargetGoal: 'Fitness',
      goalsViewModel: goalsVm,
      editHabitViewModel: editVm,
    );
    await selectionVm.loadGoals();
    await selectionVm.deleteGoal(drop);

    expect(editVm.targetGoal, isEmpty);
    expect(editVm.targetGoalId, isNull);
    expect(goalsVm.goals, isEmpty);
  });
}

class _FakeGoalService extends GoalService {
  _FakeGoalService() : super(AuthService(SecureStore()));

  List<UserGoal> items = [];
  final deleted = <UserGoal>[];

  @override
  Future<List<UserGoal>> getGoals() async => List.of(items);

  @override
  Future<void> deleteGoal(UserGoal goal) async {
    deleted.add(goal);
    items.removeWhere((g) => g.id == goal.id && g.name == goal.name);
  }
}
