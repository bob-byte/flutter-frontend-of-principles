import 'package:dio/dio.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/server_required_retry.dart';
import '../models/profile_text_suggestion.dart';
import '../models/recommended_goal.dart';
import '../models/recommended_habit.dart';

class AiRecommendationService {
  AiRecommendationService(this._apiClient);

  static const _aiTimeout = Duration(seconds: 120);

  final ApiClient _apiClient;

  Future<List<RecommendedHabit>> recommendHabits({
    required String culture,
    required List<String> currentHabits,
    required List<String> goals,
    String? mission,
    String? slogan,
    String? goal,
    int? gender,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.aiRecommendHabits,
        data: {
          'culture': culture,
          'goal': goal,
          'goals': goals,
          'currentHabits': currentHabits,
          'mission': mission,
          'mainSlogan': slogan,
          'gender': gender,
        },
        receiveTimeout: _aiTimeout,
      );

      final data = response.data;
      if (data is! Map) {
        throw StateError('AI returned an unexpected response.');
      }

      final map = Map<String, dynamic>.from(data);
      final rawHabits = map['habits'] ?? map['Habits'];
      if (rawHabits is! List) {
        throw StateError('AI returned no recommended habits.');
      }

      final habits = <RecommendedHabit>[];
      for (final item in rawHabits) {
        if (item is! Map) continue;
        final habit = RecommendedHabit.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (habit.name.isEmpty) continue;
        habits.add(habit);
      }

      if (habits.isEmpty) {
        throw StateError('AI returned no recommended habits.');
      }
      return habits;
    } catch (e) {
      if (isServerTechnicalWork(e)) {
        throw ServerTechnicalWorkException.from(e);
      }
      throw StateError(
        _userFacingError(e, 'Не вдалося отримати рекомендації.'),
      );
    }
  }

  Future<List<ProfileTextSuggestion>> suggestProfileText({
    required ProfileTextKind kind,
    required String culture,
    String? hint,
    String? draft,
    String? mission,
    String? slogan,
    List<String> goals = const [],
    int? gender,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.aiSuggestProfileText,
        data: {
          'kind': kind == ProfileTextKind.mission ? 'mission' : 'slogan',
          'culture': culture,
          'hint': hint,
          'draft': draft,
          'mission': mission,
          'mainSlogan': slogan,
          'goals': goals,
          'gender': gender,
        },
        receiveTimeout: _aiTimeout,
      );

      final data = response.data;
      if (data is! Map) {
        throw StateError('AI returned an unexpected response.');
      }

      final map = Map<String, dynamic>.from(data);
      final raw = map['suggestions'] ?? map['Suggestions'];
      if (raw is! List) {
        throw StateError('AI returned no suggestions.');
      }

      final suggestions = <ProfileTextSuggestion>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final suggestion = ProfileTextSuggestion.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (suggestion.text.isEmpty) continue;
        suggestions.add(suggestion);
      }

      if (suggestions.isEmpty) {
        throw StateError('AI returned no suggestions.');
      }
      return suggestions;
    } catch (e) {
      if (isServerTechnicalWork(e)) {
        throw ServerTechnicalWorkException.from(e);
      }
      throw StateError(_userFacingError(e, 'Не вдалося отримати пропозиції.'));
    }
  }

  Future<List<RecommendedGoal>> recommendGoals({
    required String culture,
    required String areaOfLife,
    List<String> existingGoals = const [],
    String? draft,
    String? mission,
    String? slogan,
    int? gender,
  }) async {
    try {
      final response = await _apiClient.post(
        ApiEndpoints.aiRecommendGoals,
        data: {
          'culture': culture,
          'areaOfLife': areaOfLife,
          'existingGoals': existingGoals,
          'draft': draft,
          'mission': mission,
          'mainSlogan': slogan,
          'gender': gender,
        },
        receiveTimeout: _aiTimeout,
      );

      final data = response.data;
      if (data is! Map) {
        throw StateError('AI returned an unexpected response.');
      }

      final map = Map<String, dynamic>.from(data);
      final rawGoals = map['goals'] ?? map['Goals'];
      if (rawGoals is! List) {
        throw StateError('AI returned no recommended goals.');
      }

      final goals = <RecommendedGoal>[];
      for (final item in rawGoals) {
        if (item is! Map) continue;
        final goal = RecommendedGoal.fromJson(Map<String, dynamic>.from(item));
        if (goal.name.isEmpty) continue;
        goals.add(goal);
      }

      if (goals.isEmpty) {
        throw StateError('AI returned no recommended goals.');
      }
      return goals;
    } catch (e) {
      if (isServerTechnicalWork(e)) {
        throw ServerTechnicalWorkException.from(e);
      }
      throw StateError(
        _userFacingError(e, 'Не вдалося отримати рекомендації цілей.'),
      );
    }
  }

  String _userFacingError(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final err = data['error'] ?? data['Error'] ?? data['title'];
        if (err != null && err.toString().trim().isNotEmpty) {
          return err.toString().trim();
        }
      } else if (data is String && data.trim().isNotEmpty) {
        return data.trim();
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return 'Увійдіть в акаунт, щоб користуватися AI.';
      }
      if (e.response?.statusCode == 429) {
        return 'Закінчилась квота OpenAI на сервері. Поповніть баланс.';
      }
      if (e.response?.statusCode == 503) {
        return 'AI ще не налаштований на сервері.';
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Немає з\'єднання з AI-сервером. Запустіть бекенд або перевірте інтернет.';
      }
    }
    final text = e
        .toString()
        .replaceFirst(RegExp(r'^Bad state:\s*'), '')
        .trim();
    return text.isEmpty ? fallback : text;
  }
}
