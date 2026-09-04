import 'package:flutter/foundation.dart';
import '../../models/user_goal.dart';
import '../../services/goal_service.dart';
import '../../services/dialog_service.dart';

class AddEditGoalViewModel extends ChangeNotifier {
  final GoalService _goalService;
  final DialogService _dialogService = DialogService();

  final UserGoal? existingGoal;
  String text = '';
  bool isCompleted = false;
  bool _completionChanged = false;

  AddEditGoalViewModel(this._goalService, {this.existingGoal}) {
    if (existingGoal != null) {
      text = existingGoal!.name;
      isCompleted = existingGoal!.isCompleted;
    }
  }

  bool get canToggleCompleted => existingGoal != null;

  void updateText(String newText) {
    text = newText;
    notifyListeners();
  }

  Future<void> toggleCompleted() async {
    if (existingGoal == null) return;
    isCompleted = !isCompleted;
    _completionChanged = true;
    notifyListeners();

    final name = text.trim().isEmpty ? existingGoal!.name : text.trim();
    await _goalService.updateGoal(
      existingGoal!,
      existingGoal!.copyWith(
        name: name,
        isCompleted: isCompleted,
        lastModified: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> saveGoal() async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (existingGoal != null) {
      await _goalService.updateGoal(
        existingGoal!,
        existingGoal!.copyWith(
          name: trimmed,
          isCompleted: isCompleted,
          lastModified: DateTime.now().toUtc(),
        ),
      );
    } else {
      final newGoal = UserGoal(name: trimmed);
      await _goalService.saveGoal(newGoal);
    }

    _dialogService.completeDialog(DialogResponse(confirmed: true));
  }

  void cancel() {
    _dialogService.completeDialog(
      DialogResponse(confirmed: _completionChanged),
    );
  }
}
