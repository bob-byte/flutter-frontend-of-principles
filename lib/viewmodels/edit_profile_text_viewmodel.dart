import 'package:flutter/foundation.dart';

import '../core/network/server_required_retry.dart';
import '../models/profile_text_suggestion.dart';
import '../services/ai_recommendation_service.dart';
import '../services/goal_service.dart';
import '../services/user_service.dart';

class EditProfileTextViewModel extends ChangeNotifier {
  EditProfileTextViewModel({
    required ProfileTextKind kind,
    UserService? userService,
    AiRecommendationService? aiRecommendationService,
    GoalService? goalService,
    ServerRequiredRetry? serverRetry,
    this.draftMode = false,
    this.draftGender,
    String initialText = '',
  }) : kind = kind,
       _userService = userService,
       _ai = aiRecommendationService,
       _goalService = goalService,
       _serverRetry = serverRetry ?? ServerRequiredRetry(),
       text = initialText;

  final ProfileTextKind kind;
  final UserService? _userService;
  final AiRecommendationService? _ai;
  final GoalService? _goalService;
  final ServerRequiredRetry _serverRetry;
  final bool draftMode;
  final int? draftGender;

  String text;
  String hint = '';
  List<ProfileTextSuggestion> suggestions = [];
  bool isSaving = false;
  bool isSuggesting = false;
  String? error;
  String? suggestError;

  bool get isMission => kind == ProfileTextKind.mission;
  bool get canSuggestWithAi => _ai != null;

  void updateText(String value) {
    text = value;
    notifyListeners();
  }

  void updateHint(String value) {
    hint = value;
    notifyListeners();
  }

  void applySuggestion(ProfileTextSuggestion suggestion) {
    text = suggestion.text;
    notifyListeners();
  }

  /// Confirms the current draft without writing to the profile.
  String confirmDraft() {
    final trimmed = text.trim();
    text = trimmed;
    notifyListeners();
    return trimmed;
  }

  Future<bool> save() async {
    if (draftMode) {
      confirmDraft();
      return true;
    }
    final users = _userService;
    if (users == null) {
      error = 'User service is not available.';
      notifyListeners();
      return false;
    }
    if (isSaving) return false;
    isSaving = true;
    error = null;
    notifyListeners();
    try {
      final trimmed = text.trim();
      if (isMission) {
        await users.saveMission(trimmed);
      } else {
        await users.saveMainSlogan(trimmed);
      }
      text = trimmed;
      return true;
    } catch (e) {
      error = e.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> suggestWithAi({required String culture}) async {
    final ai = _ai;
    if (ai == null || isSuggesting) return false;
    isSuggesting = true;
    suggestError = null;
    notifyListeners();
    try {
      String? mission;
      String? slogan;
      int? gender = draftGender;
      final goals = <String>[];
      final users = _userService;
      if (users != null && !draftMode) {
        final user = await users.getCurrentUser();
        mission = user.mission;
        slogan = user.mainSlogan;
        gender = user.gender;
      }

      final goalService = _goalService;
      if (goalService != null && !draftMode) {
        try {
          final items = await goalService.getGoals();
          for (final item in items) {
            final name = item.name.trim();
            if (name.isNotEmpty) goals.add(name);
          }
        } catch (e) {
          debugPrint('Load goals for profile text AI failed: $e');
        }
      }

      final result = await _serverRetry.run(
        () => ai.suggestProfileText(
          kind: kind,
          culture: culture,
          hint: hint.trim().isEmpty ? null : hint.trim(),
          draft: text.trim().isEmpty ? null : text.trim(),
          mission: mission,
          slogan: slogan,
          goals: goals,
          gender: gender,
        ),
      );
      if (result == null) {
        suggestError =
            'Technical work on our server is in progress. Please try again later.';
        return true;
      }
      suggestions = result;
      return true;
    } catch (e) {
      suggestError = e.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
      debugPrint('Suggest profile text error: $e');
      return true;
    } finally {
      isSuggesting = false;
      notifyListeners();
    }
  }
}
