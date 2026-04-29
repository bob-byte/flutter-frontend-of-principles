import 'dart:async';

class AiChatService {
  final List<String> _history = [];

  Stream<String> streamAnswer(String prompt, {required String fallbackResponse}) async* {
    _history.add(prompt);
    for (final part in fallbackResponse.split(' ')) {
      await Future<void>.delayed(const Duration(milliseconds: 70));
      yield '$part ';
    }
  }

  void addAssistantAnswer(String text) {
    _history.add(text);
  }

  void clearChat() {
    _history.clear();
  }
}
