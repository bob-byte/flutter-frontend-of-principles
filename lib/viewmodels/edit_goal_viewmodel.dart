import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/server_required_retry.dart';
import '../models/habit.dart';
import '../models/recommended_habit.dart';
import '../models/user_goal.dart';
import '../services/ai_recommendation_service.dart';
import '../services/database_service.dart';
import '../services/goal_service.dart';
import '../services/habit_service.dart';
import '../services/user_service.dart';
import 'habit_progress_viewmodel.dart';

class EditGoalViewModel extends ChangeNotifier {
  EditGoalViewModel(
    this._goalService, {
    DatabaseService? database,
    HabitService? habitService,
    AiRecommendationService? aiRecommendationService,
    UserService? userService,
    ServerRequiredRetry? serverRetry,
    UserGoal? existingGoal,
  }) : _database = database,
       _habitService = habitService,
       _aiRecommendationService = aiRecommendationService,
       _userService = userService,
       _serverRetry = serverRetry ?? ServerRequiredRetry() {
    goal = existingGoal;
    if (existingGoal != null) {
      name = existingGoal.name;
      notes = existingGoal.notes;
      isCompleted = existingGoal.isCompleted;
    }
    _rememberSnapshot();
  }

  final GoalService _goalService;
  final DatabaseService? _database;
  final HabitService? _habitService;
  final AiRecommendationService? _aiRecommendationService;
  final UserService? _userService;
  final ServerRequiredRetry _serverRetry;

  UserGoal? goal;
  String name = '';
  String notes = '';
  bool isCompleted = false;
  bool isSaving = false;
  bool isGenerating = false;
  bool hasChanges = false;
  String? generateError;
  List<Habit> habits = [];
  List<RecommendedHabit> recommendations = [];

  String _snapshotName = '';
  String _snapshotNotes = '';
  bool _snapshotCompleted = false;

  bool get isEditing => goal != null;

  bool get canToggleCompleted => goal != null;

  bool get isDirty =>
      name.trim() != _snapshotName ||
      notes.trim() != _snapshotNotes ||
      isCompleted != _snapshotCompleted;

  void updateName(String value) {
    name = value;
    notifyListeners();
  }

  void updateNotes(String value) {
    notes = value;
    notifyListeners();
  }

  void syncFrom(List<Habit> allHabits) {
    final current = goal;
    habits = current == null ? [] : habitsForGoal(allHabits, current);
    notifyListeners();
  }

  Future<void> refreshFromDatabase() async {
    final database = _database;
    final current = goal;
    if (database == null || current == null) return;
    try {
      final all = await database.getAllHabits(isArchived: false);
      habits = habitsForGoal(all, current);
      notifyListeners();
    } catch (e) {
      debugPrint('Load goal habits failed: $e');
    }
  }

  Future<bool> save() async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    isSaving = true;
    notifyListeners();
    try {
      final notesTrimmed = notes.trim();
      final current = goal;
      if (current == null) {
        goal = await _goalService.saveGoal(
          UserGoal(
            name: trimmed,
            notes: notesTrimmed,
            isCompleted: isCompleted,
          ),
        );
      } else {
        goal = await _goalService.updateGoal(
          current,
          current.copyWith(
            name: trimmed,
            notes: notesTrimmed,
            isCompleted: isCompleted,
            lastModified: DateTime.now().toUtc(),
          ),
        );
      }
      _rememberSnapshot();
      hasChanges = true;
      return true;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  /// Persists when the form changed. Returns the stored goal.
  Future<UserGoal?> ensureSaved() async {
    if (goal != null && !isDirty) return goal;
    final ok = await save();
    return ok ? goal : null;
  }

  Future<bool> toggleCompleted() async {
    if (goal == null) return false;
    isCompleted = !isCompleted;
    notifyListeners();
    final ok = await save();
    if (!ok) {
      isCompleted = !isCompleted;
      notifyListeners();
    }
    return ok;
  }

  Future<bool> generateHabits({required String culture}) async {
    if (isGenerating) return false;
    final saved = await ensureSaved();
    if (saved == null) return false;

    final ai = _aiRecommendationService;
    final users = _userService;
    if (ai == null || users == null) {
      generateError = 'AI is not available.';
      notifyListeners();
      return true;
    }

    isGenerating = true;
    generateError = null;
    notifyListeners();
    try {
      final user = await users.getCurrentUser();
      final knownHabits = await _knownHabitNames();
      final goals = await _goalService.getGoals();
      final result = await _serverRetry.run(
        () => ai.recommendHabits(
          culture: culture,
          currentHabits: knownHabits,
          goals: [
            for (final item in goals)
              if (item.name.trim().isNotEmpty) item.name.trim(),
          ],
          mission: user.mission,
          slogan: user.mainSlogan,
          goal: saved.name.trim(),
          gender: user.gender,
        ),
      );
      if (result == null) {
        generateError =
            'Technical work on our server is in progress. Please try again later.';
        return true;
      }
      final taken = knownHabits.map((item) => item.toLowerCase()).toSet();
      recommendations = [
        for (final habit in result)
          if (!taken.contains(habit.name.trim().toLowerCase())) habit,
      ];
      return true;
    } catch (e) {
      generateError = e.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
      debugPrint('Recommend habits for goal error: $e');
      return true;
    } finally {
      isGenerating = false;
      notifyListeners();
    }
  }

  Future<Habit?> addRecommendedHabit(RecommendedHabit recommended) async {
    final saved = await ensureSaved();
    final database = _database;
    final habitService = _habitService;
    if (saved == null || database == null || habitService == null) return null;

    final habit = Habit(
      name: recommended.name.trim(),
      notes: recommended.reasonToFollow.trim(),
      targetGoal: saved.name,
      targetGoalId: saved.id ?? saved.localId,
    );
    final id = await database.insertHabit(habit);
    final stored = habit.copyWith(id: id);
    unawaited(
      habitService.pushHabit(stored, isNew: true).catchError((Object e) {
        debugPrint('Push recommended habit failed: $e');
        return null;
      }),
    );
    recommendations = [
      for (final item in recommendations)
        if (item.name != recommended.name) item,
    ];
    hasChanges = true;
    await refreshFromDatabase();
    if (!habits.any((item) => item.id == id)) {
      habits = [...habits, stored];
      notifyListeners();
    }
    return stored;
  }

  Habit draftHabit() {
    final saved = goal;
    return Habit(
      name: '',
      targetGoal: saved?.name ?? name.trim(),
      targetGoalId: saved?.id ?? saved?.localId,
    );
  }

  Future<List<String>> _knownHabitNames() async {
    var source = habits;
    final database = _database;
    if (database != null) {
      try {
        source = await database.getAllHabits(isArchived: false);
      } catch (e) {
        debugPrint('Load habits for recommendations failed: $e');
      }
    }
    return [
      for (final habit in source)
        if (habit.name.trim().isNotEmpty) habit.name.trim(),
    ];
  }

  void _rememberSnapshot() {
    _snapshotName = name.trim();
    _snapshotNotes = notes.trim();
    _snapshotCompleted = isCompleted;
  }
}
