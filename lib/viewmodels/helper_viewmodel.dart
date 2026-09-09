import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/server_required_retry.dart';
import '../models/ai_chat_message.dart';
import '../models/ai_conversation.dart';
import '../services/ai_chat_service.dart';
import '../services/ai_conversation_service.dart';
import '../services/ai_conversation_storage.dart';

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.isComplete = true,
    this.id,
  });

  String text;
  final bool isUser;
  bool isComplete;
  String? id;
}

class HelperViewModel extends ChangeNotifier {
  HelperViewModel(
    this._aiChatService,
    this._conversationService, {
    ServerRequiredRetry? serverRetry,
  }) : _serverRetry = serverRetry ?? ServerRequiredRetry();

  final AiChatService _aiChatService;
  final AiConversationService _conversationService;
  final ServerRequiredRetry _serverRetry;
  int _askEpoch = 0;

  final List<ChatMessage> messages = [];
  final List<AiConversation> conversations = [];

  String? activeConversationId;
  bool isBusy = false;
  bool isLoading = false;
  bool sidebarOpen = false;
  String searchQuery = '';
  StreamSubscription<String>? _subscription;
  bool _loaded = false;

  List<AiConversation> get filteredConversations {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(conversations);
    return [
      for (final c in conversations)
        if (c.title.toLowerCase().contains(q)) c,
    ];
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  /// Reloads sidebar chats from SQLite. Launch hydrate calls this after
  /// bootstrap merge so a first empty paint is not sticky.
  Future<void> load({bool silent = false}) async {
    if (silent && _loaded) {
      await refreshConversations();
      return;
    }
    if (!silent) {
      isLoading = true;
      notifyListeners();
    }
    try {
      await refreshConversations();
      final hasOpenChat = activeConversationId != null || messages.isNotEmpty;
      if (conversations.isNotEmpty && !hasOpenChat) {
        await openConversation(conversations.first.id);
      } else if (conversations.isEmpty && !_loaded) {
        startNewChat(notify: false);
      }
      _loaded = true;
    } finally {
      if (!silent) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshConversations() async {
    final list = await _conversationService.listConversations();
    conversations
      ..clear()
      ..addAll(list);
    notifyListeners();
  }

  void setSidebarOpen(bool open) {
    if (sidebarOpen == open) return;
    sidebarOpen = open;
    notifyListeners();
  }

  void toggleSidebar() => setSidebarOpen(!sidebarOpen);

  void setSearchQuery(String value) {
    if (searchQuery == value) return;
    searchQuery = value;
    notifyListeners();
  }

  void startNewChat({bool notify = true}) {
    if (isBusy) {
      unawaited(cancel());
    }
    activeConversationId = null;
    messages.clear();
    sidebarOpen = false;
    if (notify) notifyListeners();
  }

  Future<void> openConversation(String id) async {
    if (isBusy) {
      await cancel();
    }
    final conversation = await _conversationService.getConversation(id);
    if (conversation == null) return;

    activeConversationId = conversation.id;
    messages
      ..clear()
      ..addAll([
        for (final m in conversation.messages)
          ChatMessage(
            id: m.id,
            text: m.content,
            isUser: m.isUser,
            isComplete: true,
          ),
      ]);
    sidebarOpen = false;
    notifyListeners();
  }

  Future<void> deleteConversation(String id) async {
    await _conversationService.deleteConversation(id);
    conversations.removeWhere((c) => c.id == id);
    if (activeConversationId == id) {
      startNewChat(notify: false);
    }
    notifyListeners();
  }

  Future<void> ask(
    String prompt, {
    required String fallbackAnswer,
    required String errorMessage,
  }) async {
    if (prompt.trim().isEmpty || isBusy) return;

    final epoch = ++_askEpoch;
    final wasNew = activeConversationId == null;
    final conversationId =
        activeConversationId ?? AiConversationStorage.newId();
    activeConversationId = conversationId;

    isBusy = true;
    final userMsg = ChatMessage(
      id: AiConversationStorage.newId(),
      text: prompt,
      isUser: true,
    );
    messages.add(userMsg);
    final assistant = ChatMessage(
      id: AiConversationStorage.newId(),
      text: '',
      isUser: false,
      isComplete: false,
    );
    messages.add(assistant);
    notifyListeners();

    if (wasNew) {
      final now = DateTime.now().toUtc();
      final draft = AiConversation(
        id: conversationId,
        title: AiConversationService.placeholderTitle(prompt),
        createdAt: now,
        updatedAt: now,
        hasAiTitle: false,
        messages: [
          AiChatMessageModel(
            id: userMsg.id!,
            conversationId: conversationId,
            role: 'user',
            content: prompt,
            sortOrder: 0,
            createdAt: now,
          ),
        ],
      );
      await _conversationService.saveConversation(draft);
      await refreshConversations();
    } else {
      await _persistCurrentMessages(titleHint: null, hasAiTitle: null);
    }

    _listenAnswer(
      prompt: prompt,
      assistant: assistant,
      wasNew: wasNew,
      fallbackAnswer: fallbackAnswer,
      errorMessage: errorMessage,
      epoch: epoch,
    );
  }

  void _listenAnswer({
    required String prompt,
    required ChatMessage assistant,
    required bool wasNew,
    required String fallbackAnswer,
    required String errorMessage,
    required int epoch,
  }) {
    _subscription = _aiChatService
        .streamAnswer(
          messages: _apiMessages(),
          fallbackResponse: fallbackAnswer,
          errorMessage: errorMessage,
        )
        .listen(
          (chunk) {
            if (epoch != _askEpoch) return;
            assistant.text += chunk;
            notifyListeners();
          },
          onDone: () {
            if (epoch != _askEpoch) return;
            unawaited(_onAssistantDone(assistant, wasNew: wasNew));
          },
          onError: (error) {
            unawaited(
              _onAssistantError(
                error,
                prompt: prompt,
                assistant: assistant,
                wasNew: wasNew,
                fallbackAnswer: fallbackAnswer,
                errorMessage: errorMessage,
                epoch: epoch,
              ),
            );
          },
          cancelOnError: true,
        );
  }

  /// History for `/ai/chat` — complete turns only (skip the streaming bubble).
  List<Map<String, String>> _apiMessages() {
    final out = <Map<String, String>>[];
    for (final m in messages) {
      if (!m.isUser && !m.isComplete) continue;
      if (m.isUser) {
        out.add({'role': 'user', 'content': m.text});
      } else if (m.text.trim().isNotEmpty) {
        out.add({'role': 'assistant', 'content': m.text});
      }
    }
    return out;
  }

  Future<void> _onAssistantError(
    Object error, {
    required String prompt,
    required ChatMessage assistant,
    required bool wasNew,
    required String fallbackAnswer,
    required String errorMessage,
    required int epoch,
  }) async {
    if (epoch != _askEpoch) return;
    if (isServerTechnicalWork(error) && await _serverRetry.offerRetry()) {
      if (epoch != _askEpoch) return;
      assistant.text = '';
      notifyListeners();
      _listenAnswer(
        prompt: prompt,
        assistant: assistant,
        wasNew: wasNew,
        fallbackAnswer: fallbackAnswer,
        errorMessage: errorMessage,
        epoch: epoch,
      );
      return;
    }
    if (epoch != _askEpoch) return;
    assistant.isComplete = true;
    assistant.text = assistant.text.isEmpty ? errorMessage : assistant.text;
    isBusy = false;
    unawaited(_persistCurrentMessages(titleHint: null, hasAiTitle: null));
    notifyListeners();
  }

  Future<void> _onAssistantDone(
    ChatMessage assistant, {
    required bool wasNew,
  }) async {
    assistant.isComplete = true;
    isBusy = false;
    notifyListeners();

    final existing = activeConversationId == null
        ? null
        : await _conversationService.getConversation(activeConversationId!);
    final needsTitle = wasNew || existing == null || !existing.hasAiTitle;

    await _persistCurrentMessages(
      titleHint: existing?.title,
      hasAiTitle: existing?.hasAiTitle,
    );

    if (needsTitle) {
      await _requestAiTitle();
    } else {
      await refreshConversations();
    }
  }

  Future<void> _requestAiTitle() async {
    final id = activeConversationId;
    if (id == null) return;

    String? userText;
    String? assistantText;
    for (final m in messages) {
      if (m.isUser && userText == null) userText = m.text;
      if (!m.isUser && m.isComplete && m.text.trim().isNotEmpty) {
        assistantText = m.text;
        break;
      }
    }
    if (userText == null || userText.trim().isEmpty) return;

    final title = await _conversationService.requestTitle(
      userMessage: userText,
      assistantMessage: assistantText,
    );
    if (title == null || title.isEmpty) {
      await refreshConversations();
      return;
    }

    final current = await _conversationService.getConversation(id);
    if (current == null) return;
    await _conversationService.saveConversation(
      current.copyWith(title: title, hasAiTitle: true),
    );
    await refreshConversations();
  }

  Future<void> _persistCurrentMessages({
    String? titleHint,
    bool? hasAiTitle,
  }) async {
    final id = activeConversationId;
    if (id == null) return;

    final existing = await _conversationService.getConversation(id);
    final now = DateTime.now().toUtc();
    String? firstUserText;
    for (final m in messages) {
      if (m.isUser) {
        firstUserText = m.text;
        break;
      }
    }
    final title =
        titleHint ??
        existing?.title ??
        AiConversationService.placeholderTitle(firstUserText ?? '');

    final storedMessages = <AiChatMessageModel>[];
    var order = 0;
    for (final m in messages) {
      if (!m.isUser && !m.isComplete && m.text.trim().isEmpty) continue;
      storedMessages.add(
        AiChatMessageModel(
          id: m.id ?? AiConversationStorage.newId(),
          conversationId: id,
          role: m.isUser ? 'user' : 'assistant',
          content: m.text,
          sortOrder: order++,
          createdAt: now,
        ),
      );
    }

    final conversation = AiConversation(
      id: id,
      serverId: existing?.serverId,
      title: title,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      messages: storedMessages,
      hasAiTitle: hasAiTitle ?? existing?.hasAiTitle ?? false,
    );
    await _conversationService.saveConversation(conversation);
  }

  Future<void> cancel() async {
    _askEpoch++;
    await _subscription?.cancel();
    isBusy = false;
    if (messages.isNotEmpty &&
        !messages.last.isUser &&
        !messages.last.isComplete) {
      messages.last.isComplete = true;
      if (messages.last.text.trim().isEmpty) {
        messages.removeLast();
      }
      await _persistCurrentMessages(titleHint: null, hasAiTitle: null);
    }
    notifyListeners();
  }

  /// Removes [index] and everything after, syncs AI history, returns the text
  /// to put back in the composer. Only user messages can be edited.
  Future<String?> prepareEditUserMessage(int index) async {
    if (index < 0 || index >= messages.length) return null;
    final message = messages[index];
    if (!message.isUser) return null;

    if (isBusy) {
      await cancel();
    }

    final text = message.text;
    messages.removeRange(index, messages.length);
    await _persistCurrentMessages(titleHint: null, hasAiTitle: null);
    notifyListeners();
    return text;
  }

  void clear() {
    _askEpoch++;
    _subscription?.cancel();
    messages.clear();
    conversations.clear();
    activeConversationId = null;
    sidebarOpen = false;
    searchQuery = '';
    isBusy = false;
    _loaded = false;
    notifyListeners();
  }
}
