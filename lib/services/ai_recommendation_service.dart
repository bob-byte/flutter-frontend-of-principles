import '../models/recommended_habit.dart';
import '../models/user_habit.dart';

class AiRecommendationService {
  Future<List<RecommendedHabit>> recommendHabits({
    required List<UserHabit> currentHabits,
    required String? mission,
    required String? slogan,
    required String? goal,
    List<RecommendedHabit>? localizedFallbacks,
  }) async {
    if (localizedFallbacks != null && localizedFallbacks.isNotEmpty) {
      return localizedFallbacks;
    }
    return [];
  }
}
