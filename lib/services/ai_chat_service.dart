import 'dart:async';

class AiChatService {
  final List<String> _history = [];

  Stream<String> streamAnswer(String prompt) async* {
    _history.add(prompt);
    const response = 'I hear you. Let us break this down into one small action for today.';
    for (final part in response.split(' ')) {
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
