import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/ai_chat_service.dart';

class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.isComplete = true,
  });

  String text;
  final bool isUser;
  bool isComplete;
}

class HelperViewModel extends ChangeNotifier {
  HelperViewModel(this._aiChatService);

  final AiChatService _aiChatService;
  final List<ChatMessage> messages = [];
  bool isBusy = false;
  StreamSubscription<String>? _subscription;

  Future<void> ask(String prompt) async {
    if (prompt.trim().isEmpty || isBusy) return;

    isBusy = true;
    messages.add(ChatMessage(text: prompt, isUser: true));
    final assistant = ChatMessage(text: '', isUser: false, isComplete: false);
    messages.add(assistant);
    notifyListeners();

    _subscription = _aiChatService.streamAnswer(prompt).listen(
      (chunk) {
        assistant.text += chunk;
        notifyListeners();
      },
      onDone: () {
        assistant.isComplete = true;
        _aiChatService.addAssistantAnswer(assistant.text);
        isBusy = false;
        notifyListeners();
      },
      onError: (_) {
        assistant.isComplete = true;
        assistant.text = assistant.text.isEmpty ? 'Error occurred' : assistant.text;
        isBusy = false;
        notifyListeners();
      },
      cancelOnError: true,
    );
  }

  Future<void> cancel() async {
    await _subscription?.cancel();
    isBusy = false;
    notifyListeners();
  }

  void clear() {
    _aiChatService.clearChat();
    messages.clear();
    notifyListeners();
  }
}
