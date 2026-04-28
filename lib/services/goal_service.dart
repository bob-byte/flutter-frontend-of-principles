import '../models/user_goal.dart';

class GoalService {
  final List<UserGoal> _goals = [];

  Future<List<UserGoal>> getGoals() async => List.unmodifiable(_goals);

  Future<void> saveGoal(UserGoal goal) async {
    _goals.add(goal);
  }
}
