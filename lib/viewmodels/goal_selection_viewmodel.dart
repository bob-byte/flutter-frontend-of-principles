import 'package:flutter/foundation.dart';

import '../models/user_goal.dart';
import '../services/dialog_service.dart';
import '../services/goal_service.dart';

class GoalSelectionViewModel extends ChangeNotifier {
  final GoalService _goalService;
  final DialogService _dialogService = DialogService();

  final String currentTargetGoal;

  List<UserGoal> goals = [];
  bool isLoading = true;

  GoalSelectionViewModel(this._goalService, {required this.currentTargetGoal}) {
    loadGoals();
  }

  Future<void> loadGoals() async {
    isLoading = true;
    notifyListeners();

    goals = List.of(await _goalService.getGoals())
      ..sort(UserGoal.compareForDisplay);

    isLoading = false;
    notifyListeners();
  }

  Future<bool> confirmDeleteGoal(UserGoal goal) {
    return _dialogService.showConfirmAsync(
      msg: _dialogService.l10n.deleteGoalMessage,
      title: _dialogService.l10n.deleteGoalQuestion,
    );
  }

  Future<void> deleteGoal(UserGoal goal) async {
    await _goalService.deleteGoal(goal);
    await loadGoals();
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
    await loadGoals();
    _dialogService.showToast(
      isCompleted
          ? _dialogService.l10n.goalMarkedCompleted
          : _dialogService.l10n.goalMarkedIncomplete,
    );
  }

  Future<void> showAddEditGoalDialog({UserGoal? existingGoal}) async {
    final response = await _dialogService.showCustomDialog(
      variant: DialogType.addEditGoal,
      data: existingGoal,
    );

    if (response != null && response.confirmed == true) {
      await loadGoals();
    }
  }

  void selectGoal(UserGoal goal) {
    _dialogService.completeSheet(SheetResponse(confirmed: true, data: goal));
  }
}
