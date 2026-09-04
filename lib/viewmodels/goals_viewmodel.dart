import 'package:flutter/foundation.dart';

import '../models/user_goal.dart';
import '../services/dialog_service.dart';
import '../services/goal_service.dart';

class GoalsViewModel extends ChangeNotifier {
  GoalsViewModel(this._goalService, this._dialogService);

  final GoalService _goalService;
  final DialogService _dialogService;
  final List<UserGoal> goals = [];
  bool isLoading = false;

  Future<void> load({bool silent = false}) async {
    final showSpinner = !silent && goals.isEmpty;
    if (showSpinner) {
      isLoading = true;
      notifyListeners();
    }
    try {
      final data = await _goalService.getGoals();
      goals
        ..clear()
        ..addAll(_sorted(data));
    } finally {
      if (isLoading) {
        isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> addGoal(String name) async {
    if (name.trim().isEmpty) return;
    await _goalService.saveGoal(UserGoal(name: name.trim()));
    await load();
  }

  Future<void> editGoal(UserGoal goal) async {
    final response = await _dialogService.showCustomDialog(
      variant: DialogType.addEditGoal,
      data: goal,
    );
    if (response != null && response.confirmed) {
      await load();
    }
  }

  Future<bool> confirmDeleteGoal(UserGoal goal) {
    return _dialogService.showConfirmAsync(
      msg: _dialogService.l10n.deleteGoalMessage,
      title: _dialogService.l10n.deleteGoalQuestion,
    );
  }

  Future<void> deleteGoal(UserGoal goal) async {
    await _goalService.deleteGoal(goal);
    goals.removeWhere((item) => item.id == goal.id && item.name == goal.name);
    notifyListeners();
  }

  void clear() {
    goals.clear();
    isLoading = false;
    notifyListeners();
  }

  Future<void> setGoalCompleted(
    UserGoal goal, {
    required bool isCompleted,
  }) async {
    if (goal.isCompleted == isCompleted) return;
    await _goalService.updateGoal(
      goal,
      goal.copyWith(isCompleted: isCompleted),
    );
    await load();
    _dialogService.showToast(
      isCompleted
          ? _dialogService.l10n.goalMarkedCompleted
          : _dialogService.l10n.goalMarkedIncomplete,
    );
  }

  List<UserGoal> _sorted(Iterable<UserGoal> data) {
    final list = data.toList()..sort(UserGoal.compareForDisplay);
    return list;
  }
}
