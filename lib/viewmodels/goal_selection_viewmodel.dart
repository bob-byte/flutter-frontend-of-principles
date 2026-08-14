import 'package:flutter/foundation.dart';
import '../../models/user_goal.dart';
import '../../services/goal_service.dart';
import '../../services/dialog_service.dart';

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

    goals = await _goalService.getGoals();
    
    isLoading = false;
    notifyListeners();
  }

  Future<void> deleteGoal(UserGoal goal) async {
    await _goalService.deleteGoal(goal);
    await loadGoals();
  }

  Future<void> showAddEditGoalDialog({UserGoal? existingGoal}) async {
    final response = await _dialogService.showCustomDialog(
      variant: DialogType.addEditGoal,
      data: existingGoal,
    );

    if (response != null && response.confirmed == true) {
      // Reload goals since a new one was added or existing was updated
      await loadGoals();
    }
  }

  void selectGoal(UserGoal goal) {
    _dialogService.completeSheet(SheetResponse(confirmed: true, data: goal));
  }
}
