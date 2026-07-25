import 'dart:convert';

import '../models/ai_task_draft.dart';
import 'openai_client.dart';

class AiChatService {
  AiChatService({required OpenAiClient openAiClient}) : _openAi = openAiClient;

  final OpenAiClient _openAi;
  final List<Map<String, String>> _messages = [];

  Stream<String> streamAnswer(
    String prompt, {
    required String fallbackResponse,
    required String errorMessage,
  }) async* {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;

    if (_messages.isEmpty) {
      _messages.add({
        'role': 'system',
        'content': _helperSystemPrompt,
      });
    }

    _messages.add({'role': 'user', 'content': trimmed});

    final buffer = StringBuffer();
    try {
      await for (final chunk in _openAi.streamComplete(messages: _messages)) {
        buffer.write(chunk);
        yield chunk;
      }
      final answer = buffer.toString().trim();
      if (answer.isEmpty) {
        yield fallbackResponse;
        _messages.add({'role': 'assistant', 'content': fallbackResponse});
      } else {
        _messages.add({'role': 'assistant', 'content': answer});
      }
    } catch (_) {
      // Прибираємо невдале user-повідомлення з історії.
      if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
        _messages.removeLast();
      }
      yield errorMessage;
    }
  }

  void addAssistantAnswer(String text) {
    // Відповідь уже додається в streamAnswer; метод лишається для сумісності VM.
    if (text.trim().isEmpty) return;
    if (_messages.isEmpty || _messages.last['role'] != 'assistant') {
      _messages.add({'role': 'assistant', 'content': text.trim()});
    }
  }

  void clearChat() {
    _messages.clear();
  }

  /// Аналізує текст користувача через OpenAI і збирає поля завдання.
  Future<AiTaskDraft> parseTaskDraft(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return const AiTaskDraft(title: '');
    }

    final today = DateTime.now();
    final todayIso =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';

    final content = await _openAi.complete(
      jsonObject: true,
      maxCompletionTokens: 800,
      messages: [
        {
          'role': 'system',
          'content': '''
You convert messy spoken or typed user text into one todo task.
Reply with ONLY a JSON object:
{
  "title": "short clear task title",
  "description": "cleaned useful details; empty string if none",
  "priority": "high" | "medium" | "low" | null,
  "theme": "category name or null",
  "dueDate": "YYYY-MM-DD or null"
}
Rules:
- Fix grammar, word order, and speech-to-text noise.
- Do not dump raw speech into title or description.
- Title must be concise (usually verb + object).
- Description holds details/lists, nicely phrased.
- Match the user's language.
- Today is $todayIso.
''',
        },
        {'role': 'user', 'content': trimmed},
      ],
    );

    final json = _extractJsonObject(content);
    final draft = AiTaskDraft.fromJson(json);
    if (draft.title.isEmpty) {
      throw StateError('AI returned a task without a title.');
    }
    return draft;
  }

  Map<String, dynamic> _extractJsonObject(String content) {
    var text = content.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*', multiLine: false), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
      text = text.trim();
    }

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) {
      text = text.substring(start, end + 1);
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('AI JSON is not an object.');
    }
    return decoded;
  }

  static const _helperSystemPrompt =
      'You are a self-development helper, but you can answer any question. '
      'If the user asks something unrelated to self-development, respond normally '
      'without forcing that topic. Support the user in building better habits and '
      'growing, but do not lecture unsolicited. Do not accept weak conclusions as true: '
      'be an intellectual opponent when useful. '
      'If you generate code, do not wrap it in ``` fences; put the language name on a line before the code.';
}
