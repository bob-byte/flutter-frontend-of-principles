import '../models/recommended_habit.dart';
import '../models/user_habit.dart';

class AiRecommendationService {
  Future<List<RecommendedHabit>> recommendHabits({
    required List<UserHabit> currentHabits,
    required String? mission,
    required String? slogan,
    required String? goal,
  }) async {
    return [
      RecommendedHabit(
        name: 'Write 3 priorities after waking up',
        reasonToFollow: 'It turns intention into focus before distractions start.',
      ),
      RecommendedHabit(
        name: 'Walk 15 minutes after lunch',
        reasonToFollow: 'It improves energy and consistency with minimal friction.',
      ),
      RecommendedHabit(
        name: 'Review one completed task before sleep',
        reasonToFollow: 'It reinforces progress and keeps motivation stable.',
      ),
      RecommendedHabit(
        name: 'Read 5 pages before bed',
        reasonToFollow: 'It creates a repeatable cue for learning and calm.',
      ),
    ];
  }
}
