import 'package:flutter/foundation.dart';

import '../models/recommended_habit.dart';
import '../models/user_habit.dart';
import '../services/ai_recommendation_service.dart';
import '../services/habit_service.dart';

class EditHabitViewModel extends ChangeNotifier {
  EditHabitViewModel({
    required HabitService habitService,
    required AiRecommendationService recommendationService,
  })  : _habitService = habitService,
        _recommendationService = recommendationService;

  final HabitService _habitService;
  final AiRecommendationService _recommendationService;

  String habitName = '';
  String habitDescription = '';
  bool isSaving = false;
  bool isRecommendationLoading = false;
  final List<RecommendedHabit> recommendations = [];

  Future<void> saveHabit() async {
    if (habitName.trim().isEmpty) return;
    isSaving = true;
    notifyListeners();
    try {
      await _habitService.saveHabit(
        UserHabit(
          name: habitName.trim(),
          description: habitDescription.trim(),
        ),
      );
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<void> loadRecommendations() async {
    isRecommendationLoading = true;
    notifyListeners();
    try {
      final currentHabits = await _habitService.getHabits();
      final data = await _recommendationService.recommendHabits(
        currentHabits: currentHabits,
        mission: null,
        slogan: null,
        goal: null,
      );
      recommendations
        ..clear()
        ..addAll(data);
    } finally {
      isRecommendationLoading = false;
      notifyListeners();
    }
  }

  void applyRecommendation(RecommendedHabit habit) {
    habitName = habit.name;
    if (habitDescription.trim().isEmpty) {
      habitDescription = habit.reasonToFollow;
    } else {
      habitDescription = '$habitDescription\n\n${habit.reasonToFollow}';
    }
    notifyListeners();
  }
}
