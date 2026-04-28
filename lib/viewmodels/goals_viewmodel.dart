import 'package:flutter/foundation.dart';

import '../models/user_goal.dart';
import '../services/goal_service.dart';

class GoalsViewModel extends ChangeNotifier {
  GoalsViewModel(this._goalService);

  final GoalService _goalService;
  final List<UserGoal> goals = [];
  bool isLoading = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      final data = await _goalService.getGoals();
      goals
        ..clear()
        ..addAll(data);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addGoal(String name) async {
    if (name.trim().isEmpty) return;
    await _goalService.saveGoal(UserGoal(name: name.trim()));
    await load();
  }
}
