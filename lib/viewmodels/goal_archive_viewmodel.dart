import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_goal.dart';
import '../services/dialog_service.dart';
import '../services/goal_service.dart';

class GoalArchiveViewModel extends ChangeNotifier {
  GoalArchiveViewModel(this._goalService) {
    loadGoals();
  }

  final GoalService _goalService;
  final DialogService _dialogService = DialogService();

  List<UserGoal> archivedGoals = [];
  bool isLoading = true;
  bool showInfoBanner = false;

  Future<void> loadGoals() async {
    isLoading = true;
    notifyListeners();

    try {
      archivedGoals = await _goalService.getArchivedGoals();
    } catch (e) {
      debugPrint('Failed to load archived goals: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> hideBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenGoalArchiveInfo', true);
    showInfoBanner = false;
    notifyListeners();
  }

  void showBanner() {
    showInfoBanner = true;
    notifyListeners();
  }

  Future<void> unarchiveGoal(UserGoal goal) async {
    final updated = await _goalService.applyLocalArchiveStatus(
      goal.copyWith(isArchived: false),
    );
    archivedGoals.removeWhere(
      (g) =>
          g.localId == goal.localId || (g.id == goal.id && g.name == goal.name),
    );
    notifyListeners();
    _goalService.setArchiveStatus(updated).catchError((e) {
      debugPrint('Failed to sync goal unarchive: $e');
      return false;
    });
  }

  Future<bool> confirmDeleteGoal(UserGoal goal) {
    return _dialogService.showConfirmAsync(
      msg: _dialogService.l10n.deleteGoalMessage,
      title: _dialogService.l10n.deleteGoalQuestion,
    );
  }

  Future<void> deleteGoal(UserGoal goal) async {
    await _goalService.deleteGoal(goal);
    archivedGoals.removeWhere(
      (g) =>
          g.localId == goal.localId || (g.id == goal.id && g.name == goal.name),
    );
    notifyListeners();
  }

  void close() {
    _dialogService.completeSheet(SheetResponse(confirmed: false));
  }
}
