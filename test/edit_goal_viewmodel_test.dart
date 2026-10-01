import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/user_goal.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:principles_app/viewmodels/edit_goal_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeGoalService goals;
  late EditGoalViewModel createVm;
  late EditGoalViewModel editVm;

  setUp(() {
    goals = _FakeGoalService();
    createVm = EditGoalViewModel(goals);
    editVm = EditGoalViewModel(
      goals,
      existingGoal: UserGoal(id: 4, name: 'Read', isCompleted: false),
    );
  });

  test('create mode starts blank and cannot toggle completed', () {
    expect(createVm.name, isEmpty);
    expect(createVm.notes, isEmpty);
    expect(createVm.canToggleCompleted, isFalse);
  });

  test('edit mode loads existing goal fields', () {
    expect(editVm.name, 'Read');
    expect(editVm.notes, isEmpty);
    expect(editVm.canToggleCompleted, isTrue);
    expect(editVm.isCompleted, isFalse);
  });

  test('updateName notifies and stores value', () {
    createVm.updateName('New goal');
    expect(createVm.name, 'New goal');
  });

  test('updateNotes notifies and stores value', () {
    createVm.updateNotes('Why this matters');
    expect(createVm.notes, 'Why this matters');
  });

  test('save does nothing for blank text', () async {
    final saved = await createVm.save();
    expect(saved, isFalse);
    expect(goals.saved, isEmpty);
  });

  test('save creates a new goal when editing none', () async {
    createVm.updateName('  Fitness  ');
    createVm.updateNotes('  Stay healthy  ');
    final saved = await createVm.save();
    expect(saved, isTrue);
    expect(goals.saved.single.name, 'Fitness');
    expect(goals.saved.single.notes, 'Stay healthy');
    expect(createVm.isEditing, isTrue);
  });

  test('save updates existing goal', () async {
    editVm.updateName('Read daily');
    editVm.updateNotes('Before bed');
    await editVm.save();
    expect(goals.updated.single.name, 'Read daily');
    expect(goals.updated.single.notes, 'Before bed');
  });

  test('ensureSaved skips a second write when nothing changed', () async {
    final goal = await editVm.ensureSaved();
    expect(goal?.name, 'Read');
    expect(goals.updated, isEmpty);
  });
}

class _FakeGoalService extends GoalService {
  _FakeGoalService() : super(AuthService(SecureStore()));

  final saved = <UserGoal>[];
  final updated = <UserGoal>[];

  @override
  Future<UserGoal> saveGoal(UserGoal goal) async {
    saved.add(goal);
    return goal.copyWith(localId: 1);
  }

  @override
  Future<UserGoal> updateGoal(UserGoal original, UserGoal updatedGoal) async {
    updated.add(updatedGoal);
    return updatedGoal;
  }
}
