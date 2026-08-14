import 'package:flutter/foundation.dart';
import '../../models/user_goal.dart';
import '../../services/goal_service.dart';
import '../../services/dialog_service.dart';

class AddEditGoalViewModel extends ChangeNotifier {
  final GoalService _goalService;
  final DialogService _dialogService = DialogService();
  
  final UserGoal? existingGoal;
  String text = '';

  AddEditGoalViewModel(this._goalService, {this.existingGoal}) {
    if (existingGoal != null) {
      text = existingGoal!.name;
    }
  }

  void updateText(String newText) {
    text = newText;
    notifyListeners();
  }

  Future<void> saveGoal() async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (existingGoal != null) {
      final newGoal = UserGoal(
        localId: existingGoal!.localId,
        id: existingGoal!.id,
        name: trimmed,
        lastModified: DateTime.now().toUtc(),
      );
      await _goalService.updateGoal(existingGoal!, newGoal);
    } else {
      final newGoal = UserGoal(name: trimmed);
      await _goalService.saveGoal(newGoal);
    }

    _dialogService.completeDialog(DialogResponse(confirmed: true));
  }

  void cancel() {
    _dialogService.completeDialog(DialogResponse(confirmed: false));
  }
}
