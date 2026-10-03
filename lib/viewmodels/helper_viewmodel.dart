import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/helper/helper_chat_actions_parser.dart';
import '../core/network/server_required_retry.dart';
import '../models/ai_chat_message.dart';
import '../models/ai_conversation.dart';
import '../models/helper_chat_message.dart';
import '../models/helper_chat_tree.dart';
import '../services/ai_chat_service.dart';
import '../services/ai_conversation_service.dart';
import '../services/ai_conversation_storage.dart';

export '../models/helper_chat_message.dart';

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

  HelperChatTree _tree = HelperChatTree();
  List<ChatMessage> _messages = const [];

  /// User prompt being rewritten in the composer; the thread is shown up to
  /// (not including) it until send adds the new text as a version.
  ChatMessage? _editing;

  /// Visible thread: the selected version at every turn.
  List<ChatMessage> get messages => UnmodifiableListView(_messages);

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

  /// Whether chats were painted into this VM (first Chat-tab open).
  bool get isLoaded => _loaded;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await load();
  }

  /// Sidebar refresh after sync — no-op until the Chat tab has loaded once.
  Future<void> refreshIfLoaded() async {
    if (!_loaded) return;
    await refreshConversations();
  }

  /// Loads sidebar chats from SQLite and leaves the composer on a new chat
  /// (does not auto-open the latest thread). An already-open chat is kept so
  /// switching shell tabs does not wipe the user's selection.
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
      if (!hasOpenChat) {
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
    _resetThread(HelperChatTree());
    sidebarOpen = false;
    if (notify) notifyListeners();
  }

  void _resetThread(HelperChatTree tree) {
    _tree = tree;
    _editing = null;
    _refreshThread();
  }

  void _refreshThread() {
    final path = _tree.activePath();
    final editing = _editing;
    if (editing != null) {
      final index = path.indexWhere((m) => identical(m, editing));
      if (index >= 0) {
        path.removeRange(index, path.length);
      } else {
        _editing = null;
      }
    }
    _messages = path;
  }

  Future<void> openConversation(String id) async {
    if (isBusy) {
      await cancel();
    }
    final conversation = await _conversationService.getConversation(id);
    if (conversation == null) return;

    final branches = await _conversationService.loadBranches(conversation.id);

    activeConversationId = conversation.id;
    _resetThread(
      HelperChatTree.restore([
        for (final m in conversation.messages)
          ChatMessage(
            id: m.id,
            text: m.content,
            isUser: m.isUser,
            isComplete: true,
          ),
      ], branches),
    );
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
    final editing = _editing;
    _editing = null;
    if (editing != null) {
      _tree.addVersion(editing, userMsg);
    } else {
      _tree.append(userMsg);
    }
    final assistant = ChatMessage(
      id: AiConversationStorage.newId(),
      text: '',
      isUser: false,
      isComplete: false,
    );
    _tree.append(assistant);
    _refreshThread();
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

  bool get isEditing => _editing != null;

  /// Whether [message] is a finished reply to a user turn on the visible thread.
  bool canRetry(ChatMessage message) {
    if (isBusy || isEditing || message.isUser || !message.isComplete) {
      return false;
    }
    final index = _messages.indexWhere((m) => identical(m, message));
    return index > 0 && _messages[index - 1].isUser;
  }

  /// Asks again for [message]'s prompt; the new answer becomes another version
  /// of that reply (later turns stay on the previous version).
  Future<void> retryAnswer(
    ChatMessage message, {
    required String fallbackAnswer,
    required String errorMessage,
  }) async {
    if (!canRetry(message)) return;

    final epoch = ++_askEpoch;
    final index = _messages.indexWhere((m) => identical(m, message));
    final prompt = _messages[index - 1].text;
    final assistant = ChatMessage(
      id: AiConversationStorage.newId(),
      text: '',
      isUser: false,
      isComplete: false,
    );
    _tree.addVersion(message, assistant);
    _refreshThread();
    isBusy = true;
    notifyListeners();

    await _persistCurrentMessages(titleHint: null, hasAiTitle: null);
    if (epoch != _askEpoch) return;

    _listenAnswer(
      prompt: prompt,
      assistant: assistant,
      wasNew: false,
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
  /// Strips machine `<<<ACTIONS>>>` trailers so they are not echoed back to the model.
  List<Map<String, String>> _apiMessages() {
    final out = <Map<String, String>>[];
    for (final m in messages) {
      if (!m.isUser && !m.isComplete) continue;
      if (m.isUser) {
        out.add({'role': 'user', 'content': m.text});
      } else if (m.text.trim().isNotEmpty) {
        out.add({
          'role': 'assistant',
          'content': helperChatDisplayText(m.text),
        });
      }
    }
    return out;
  }

  void markActionApplied(ChatMessage message, String dedupeKey) {
    if (message.appliedActionKeys.add(dedupeKey)) {
      notifyListeners();
    }
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

    final thread = _tree.activePath();
    final branches = _tree.hasVersions ? _tree.encode() : null;
    final existing = await _conversationService.getConversation(id);
    final now = DateTime.now().toUtc();
    String? firstUserText;
    for (final m in thread) {
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
    for (final m in thread) {
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
    await _conversationService.saveBranches(id, branches);
  }

  Future<void> cancel() async {
    _askEpoch++;
    await _subscription?.cancel();
    isBusy = false;
    final last = _messages.isEmpty ? null : _messages.last;
    if (last != null && !last.isUser && !last.isComplete) {
      last.isComplete = true;
      if (last.text.trim().isEmpty) {
        _tree.remove(last);
        _refreshThread();
      }
      await _persistCurrentMessages(titleHint: null, hasAiTitle: null);
    }
    notifyListeners();
  }

  /// Hides [index] and later turns and returns the prompt text for the
  /// composer. The next send adds a new version of that prompt; earlier
  /// versions stay reachable from the version switcher. Only user messages
  /// can be edited.
  Future<String?> prepareEditUserMessage(int index) async {
    if (index < 0 || index >= _messages.length) return null;
    final message = _messages[index];
    if (!message.isUser) return null;

    if (isBusy) {
      await cancel();
    }

    _editing = message;
    _refreshThread();
    notifyListeners();
    return message.text;
  }

  /// Leaves edit mode and shows the full thread again.
  void cancelEdit() {
    if (_editing == null) return;
    _editing = null;
    _refreshThread();
    notifyListeners();
  }

  /// Version position of [message] among prompts/replies at the same turn.
  ({int index, int count}) versionOf(ChatMessage message) =>
      _tree.versionOf(message);

  bool get canSwitchVersion => !isBusy && !isEditing;

  /// Shows the previous (`delta < 0`) or next version of [message] together
  /// with the replies that followed it, and syncs that thread.
  Future<void> switchVersion(ChatMessage message, int delta) async {
    if (!canSwitchVersion) return;
    if (!_tree.selectVersion(message, delta)) return;
    _refreshThread();
    notifyListeners();
    await _persistCurrentMessages(titleHint: null, hasAiTitle: null);
  }

  void clear() {
    _askEpoch++;
    _subscription?.cancel();
    _resetThread(HelperChatTree());
    conversations.clear();
    activeConversationId = null;
    sidebarOpen = false;
    searchQuery = '';
    isBusy = false;
    _loaded = false;
    notifyListeners();
  }
}
