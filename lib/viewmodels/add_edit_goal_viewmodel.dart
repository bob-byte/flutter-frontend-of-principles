import 'package:flutter/foundation.dart';
import '../../models/user_goal.dart';
import '../../services/goal_service.dart';
import '../../services/dialog_service.dart';

class AddEditGoalViewModel extends ChangeNotifier {
  final GoalService _goalService;
  final DialogService _dialogService = DialogService();

  final UserGoal? existingGoal;
  String text = '';
  String notes = '';
  bool isCompleted = false;
  bool _completionChanged = false;

  AddEditGoalViewModel(this._goalService, {this.existingGoal}) {
    if (existingGoal != null) {
      text = existingGoal!.name;
      notes = existingGoal!.notes;
      isCompleted = existingGoal!.isCompleted;
    }
  }

  bool get canToggleCompleted => existingGoal != null;

  void updateText(String newText) {
    text = newText;
    notifyListeners();
  }

  void updateNotes(String newNotes) {
    notes = newNotes;
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
        notes: notes.trim(),
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
          notes: notes.trim(),
          isCompleted: isCompleted,
          lastModified: DateTime.now().toUtc(),
        ),
      );
    } else {
      final newGoal = UserGoal(name: trimmed, notes: notes.trim());
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
