import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/user_goal.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/goal_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GoalService service;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    service = GoalService(AuthService(SecureStore()));
  });

  test('saveGoal and getGoals round-trip via prefs', () async {
    await service.saveGoal(UserGoal(name: 'Read'));
    final goals = await service.getGoals();
    expect(goals.map((g) => g.name), ['Read']);
  });

  test('updateGoal renames existing goal', () async {
    await service.saveGoal(UserGoal(name: 'Draft'));
    final original = (await service.getGoals()).single;
    await service.updateGoal(original, original.copyWith(name: 'Final'));
    expect((await service.getGoals()).single.name, 'Final');
  });

  test('clearLocal removes cached goals', () async {
    await service.saveGoal(UserGoal(name: 'Temp'));
    await service.clearLocal();
    expect(await service.getGoals(), isEmpty);
  });
}
