import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user_goal.dart';
import '../services/completion_feedback.dart';
import '../services/dialog_service.dart';
import '../services/goal_service.dart';

enum GoalStatusFilter { all, active, completed }

class GoalsViewModel extends ChangeNotifier {
  GoalsViewModel(this._goalService, this._dialogService);

  final GoalService _goalService;
  final DialogService _dialogService;
  final List<UserGoal> goals = [];
  bool isLoading = false;

  bool filtersVisible = false;
  GoalStatusFilter statusFilter = GoalStatusFilter.all;

  final Set<String> _heldCompletedGoalKeys = {};
  final Map<String, Timer> _holdCompletedTimers = {};

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

  Future<bool> confirmDeleteGoal(UserGoal goal) {
    return _dialogService.showConfirmAsync(
      msg: _dialogService.l10n.deleteGoalMessage,
      title: _dialogService.l10n.deleteGoalQuestion,
    );
  }

  Future<void> deleteGoal(UserGoal goal) async {
    _releaseHeldCompletedGoal(goal);
    await _goalService.deleteGoal(goal);
    goals.removeWhere((item) => item.id == goal.id && item.name == goal.name);
    notifyListeners();
  }

  Future<bool> confirmArchiveGoal(UserGoal goal) {
    return _dialogService.showConfirmAsync(
      msg: goal.isArchived
          ? _dialogService.l10n.unarchiveGoalMessage
          : _dialogService.l10n.archiveGoalMessage,
      title: goal.isArchived
          ? _dialogService.l10n.unarchiveGoalQuestion
          : _dialogService.l10n.archiveGoalQuestion,
    );
  }

  Future<void> archiveGoal(UserGoal goal) async {
    if (goal.isArchived) return;
    _releaseHeldCompletedGoal(goal);
    final updated = await _goalService.applyLocalArchiveStatus(
      goal.copyWith(isArchived: true),
    );
    goals.removeWhere(
      (item) =>
          item.localId == goal.localId ||
          (item.id == goal.id && item.name == goal.name),
    );
    notifyListeners();
    try {
      await _goalService.setArchiveStatus(updated);
    } catch (e) {
      debugPrint('Failed to sync goal archive: $e');
    }
  }

  Future<void> unarchiveGoal(UserGoal goal) async {
    if (!goal.isArchived) return;
    final updated = await _goalService.applyLocalArchiveStatus(
      goal.copyWith(isArchived: false),
    );
    goals
      ..removeWhere(
        (item) =>
            item.localId == goal.localId ||
            (item.id == goal.id && item.name == goal.name),
      )
      ..add(updated);
    final sorted = _sorted(goals);
    goals
      ..clear()
      ..addAll(sorted);
    notifyListeners();
    try {
      await _goalService.setArchiveStatus(updated);
    } catch (e) {
      debugPrint('Failed to sync goal unarchive: $e');
    }
  }

  void clear() {
    _clearHeldCompletedGoals();
    goals.clear();
    isLoading = false;
    filtersVisible = false;
    statusFilter = GoalStatusFilter.all;
    notifyListeners();
  }

  void toggleFiltersVisible() {
    filtersVisible = !filtersVisible;
    notifyListeners();
  }

  void setStatusFilter(GoalStatusFilter status) {
    statusFilter = status;
    notifyListeners();
  }

  void clearFilters() {
    statusFilter = GoalStatusFilter.all;
    notifyListeners();
  }

  bool get hasActiveFilters => statusFilter != GoalStatusFilter.all;

  List<UserGoal> get filteredGoals {
    return goals.where(_matchesStatusFilter).toList();
  }

  bool get showsUnassignedHabits => statusFilter != GoalStatusFilter.completed;

  bool isHeldCompletedGoal(UserGoal goal) =>
      _heldCompletedGoalKeys.contains(goalIdentityKey(goal));

  /// Treat held completed goals as still in the active section for the burst.
  bool appearsInActiveSection(UserGoal goal) =>
      !goal.isCompleted || isHeldCompletedGoal(goal);

  void holdCompletedGoal(UserGoal goal) {
    final key = goalIdentityKey(goal);
    _holdCompletedTimers[key]?.cancel();
    _heldCompletedGoalKeys.add(key);
    _holdCompletedTimers[key] = Timer(kCompletionCelebrationDuration, () {
      _heldCompletedGoalKeys.remove(key);
      _holdCompletedTimers.remove(key);
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> setGoalCompleted(
    UserGoal goal, {
    required bool isCompleted,
  }) async {
    if (goal.isCompleted == isCompleted) return;
    if (isCompleted && statusFilter == GoalStatusFilter.active) {
      holdCompletedGoal(goal);
    } else {
      _releaseHeldCompletedGoal(goal);
    }
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

  bool _matchesStatusFilter(UserGoal goal) {
    return switch (statusFilter) {
      GoalStatusFilter.all => true,
      GoalStatusFilter.active => !goal.isCompleted || isHeldCompletedGoal(goal),
      GoalStatusFilter.completed => goal.isCompleted,
    };
  }

  void _releaseHeldCompletedGoal(UserGoal goal) {
    final key = goalIdentityKey(goal);
    _holdCompletedTimers.remove(key)?.cancel();
    _heldCompletedGoalKeys.remove(key);
  }

  void _clearHeldCompletedGoals() {
    for (final timer in _holdCompletedTimers.values) {
      timer.cancel();
    }
    _holdCompletedTimers.clear();
    _heldCompletedGoalKeys.clear();
  }

  List<UserGoal> _sorted(Iterable<UserGoal> data) {
    final list = data.toList()..sort(UserGoal.compareForDisplay);
    return list;
  }
}

String goalIdentityKey(UserGoal goal) {
  if (goal.id != null) return 's:${goal.id}';
  if (goal.localId != null) return 'l:${goal.localId}';
  return 'n:${goal.name}';
}
