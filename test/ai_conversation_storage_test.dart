import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/models/ai_chat_message.dart';
import 'package:principles_app/models/ai_conversation.dart';
import 'package:principles_app/services/ai_conversation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AiConversationService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppConfig.debugUseLocalDataOverride = true;
    service = AiConversationService(apiClient: ApiClient(SecureStore()));
  });

  tearDown(() {
    AppConfig.debugUseLocalDataOverride = null;
  });

  test('saves and reloads a conversation with messages', () async {
    final now = DateTime.utc(2026, 9, 7, 12);
    final conversation = AiConversation(
      id: 'c-test-1',
      title: 'Habit tips',
      createdAt: now,
      updatedAt: now,
      hasAiTitle: true,
      messages: [
        AiChatMessageModel(
          id: 'm1',
          conversationId: 'c-test-1',
          role: 'user',
          content: 'How do I start?',
          sortOrder: 0,
          createdAt: now,
        ),
        AiChatMessageModel(
          id: 'm2',
          conversationId: 'c-test-1',
          role: 'assistant',
          content: 'Start small.',
          sortOrder: 1,
          createdAt: now,
        ),
      ],
    );

    await service.saveConversation(conversation);
    final listed = await service.listConversations();
    expect(listed, hasLength(1));
    expect(listed.first.title, 'Habit tips');

    final loaded = await service.getConversation('c-test-1');
    expect(loaded, isNotNull);
    expect(loaded!.messages, hasLength(2));
    expect(loaded.messages.first.content, 'How do I start?');
    expect(loaded.messages.last.role, 'assistant');
  });

  test('placeholderTitle truncates long prompts', () {
    expect(AiConversationService.placeholderTitle('Hi'), 'Hi');
    final long = 'a' * 50;
    expect(AiConversationService.placeholderTitle(long).endsWith('…'), isTrue);
    expect(AiConversationService.placeholderTitle(long).length, lessThan(45));
  });

  test('deleteConversation removes chat from list', () async {
    final now = DateTime.utc(2026, 9, 7, 12);
    await service.saveConversation(
      AiConversation(
        id: 'c-del',
        title: 'Gone',
        createdAt: now,
        updatedAt: now,
        messages: const [],
      ),
    );
    await service.deleteConversation('c-del');
    expect(await service.listConversations(), isEmpty);
  });
}
