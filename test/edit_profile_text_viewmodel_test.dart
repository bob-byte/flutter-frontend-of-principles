import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/server_required_retry.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/profile_text_suggestion.dart';
import 'package:principles_app/models/user.dart';
import 'package:principles_app/services/ai_recommendation_service.dart';
import 'package:principles_app/services/user_service.dart';
import 'package:principles_app/viewmodels/edit_profile_text_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAi extends AiRecommendationService {
  _FakeAi() : super(ApiClient(SecureStore()));

  List<ProfileTextSuggestion> next = const [];
  Object? throwError;
  int calls = 0;

  @override
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
    calls += 1;
    final error = throwError;
    if (error != null) throw error;
    return next;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({
      UserService.prefsKey: jsonEncode(
        User(
          name: 'Ada',
          email: 'ada@example.com',
          mainSlogan: 'Keep going',
          mission: 'Build tools',
          gender: 0,
        ).toJson(),
      ),
    });
  });

  test('applySuggestion updates text', () {
    final vm = EditProfileTextViewModel(
      kind: ProfileTextKind.slogan,
      userService: UserService(forceLocalOnly: true),
      aiRecommendationService: _FakeAi(),
      initialText: 'Old',
    );

    vm.applySuggestion(
      const ProfileTextSuggestion(
        text: 'Character over comfort',
        reason: 'Steady',
      ),
    );

    expect(vm.text, 'Character over comfort');
  });

  test('suggestWithAi fills suggestions', () async {
    final ai = _FakeAi()
      ..next = const [
        ProfileTextSuggestion(text: 'Serve first', reason: 'Clear priority'),
      ];
    final vm = EditProfileTextViewModel(
      kind: ProfileTextKind.mission,
      userService: UserService(forceLocalOnly: true),
      aiRecommendationService: ai,
      serverRetry: ServerRequiredRetry(prompt: () async => false),
      initialText: '',
    );

    await vm.suggestWithAi(culture: 'en');

    expect(ai.calls, 1);
    expect(vm.suggestions, hasLength(1));
    expect(vm.suggestions.single.text, 'Serve first');
    expect(vm.suggestError, isNull);
  });

  test('save mission persists trimmed text', () async {
    final vm = EditProfileTextViewModel(
      kind: ProfileTextKind.mission,
      userService: UserService(forceLocalOnly: true),
      aiRecommendationService: _FakeAi(),
      initialText: '  Build tools that help  ',
    );

    final ok = await vm.save();
    expect(ok, isTrue);
    expect(vm.text, 'Build tools that help');

    final user = await UserService(forceLocalOnly: true).getCurrentUser();
    expect(user.mission, 'Build tools that help');
  });

  test('draftMode confirmDraft does not require user service', () {
    final vm = EditProfileTextViewModel(
      kind: ProfileTextKind.slogan,
      draftMode: true,
      initialText: '  Character first  ',
    );

    expect(vm.confirmDraft(), 'Character first');
    expect(vm.text, 'Character first');
  });
}
