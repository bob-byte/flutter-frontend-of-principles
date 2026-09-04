import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/user_goal.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:principles_app/viewmodels/add_edit_goal_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeGoalService goals;
  late AddEditGoalViewModel createVm;
  late AddEditGoalViewModel editVm;

  setUp(() {
    goals = _FakeGoalService();
    createVm = AddEditGoalViewModel(goals);
    editVm = AddEditGoalViewModel(
      goals,
      existingGoal: UserGoal(id: 4, name: 'Read', isCompleted: false),
    );
  });

  test('create mode starts blank and cannot toggle completed', () {
    expect(createVm.text, isEmpty);
    expect(createVm.canToggleCompleted, isFalse);
  });

  test('edit mode loads existing goal fields', () {
    expect(editVm.text, 'Read');
    expect(editVm.canToggleCompleted, isTrue);
    expect(editVm.isCompleted, isFalse);
  });

  test('updateText notifies and stores value', () {
    createVm.updateText('New goal');
    expect(createVm.text, 'New goal');
  });

  test('saveGoal does nothing for blank text', () async {
    await createVm.saveGoal();
    expect(goals.saved, isEmpty);
  });

  test('saveGoal creates a new goal when editing none', () async {
    createVm.updateText('  Fitness  ');
    await createVm.saveGoal();
    expect(goals.saved.single.name, 'Fitness');
  });

  test('saveGoal updates existing goal', () async {
    editVm.updateText('Read daily');
    await editVm.saveGoal();
    expect(goals.updated.single.name, 'Read daily');
  });
}

class _FakeGoalService extends GoalService {
  _FakeGoalService() : super(AuthService(SecureStore()));

  final saved = <UserGoal>[];
  final updated = <UserGoal>[];

  @override
  Future<void> saveGoal(UserGoal goal) async {
    saved.add(goal);
  }

  @override
  Future<void> updateGoal(UserGoal original, UserGoal updatedGoal) async {
    updated.add(updatedGoal);
  }
}
