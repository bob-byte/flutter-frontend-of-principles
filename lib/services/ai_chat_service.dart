import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/network/api_endpoints.dart';
import '../models/ai_task_draft.dart';

/// AI через бекенд-проксі (серверний ключ, без CORS у браузері).
class AiChatService {
  AiChatService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.aiKeyApiBaseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 120),
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            );

  final Dio _dio;
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

    try {
      final response = await _postWithLocalFallback(
        ApiEndpoints.aiChat,
        data: {'messages': _messages},
      );
      final map = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final content =
          (map['content'] ?? map['Content'])?.toString().trim() ?? '';
      if (content.isEmpty) {
        yield fallbackResponse;
        _messages.add({'role': 'assistant', 'content': fallbackResponse});
      } else {
        yield content;
        _messages.add({'role': 'assistant', 'content': content});
      }
    } catch (e) {
      if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
        _messages.removeLast();
      }
      yield _userFacingError(e, errorMessage);
    }
  }

  void addAssistantAnswer(String text) {
    if (text.trim().isEmpty) return;
    if (_messages.isEmpty || _messages.last['role'] != 'assistant') {
      _messages.add({'role': 'assistant', 'content': text.trim()});
    }
  }

  void clearChat() {
    _messages.clear();
  }

  Future<AiTaskDraft> parseTaskDraft(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) {
      return const AiTaskDraft(title: '');
    }

    try {
      final response = await _postWithLocalFallback(
        ApiEndpoints.aiParseTask,
        data: {'prompt': trimmed},
      );

      final data = response.data;
      if (data is! Map) {
        throw StateError('AI повернув неочікувану відповідь.');
      }

      final draft = AiTaskDraft.fromJson(Map<String, dynamic>.from(data));
      if (draft.title.isEmpty) {
        throw StateError('AI повернув завдання без назви.');
      }
      return draft;
    } catch (e) {
      throw StateError(_userFacingError(e, 'Не вдалося обробити запит.'));
    }
  }

  /// Прод → якщо недоступний у debug, локальний бекенд.
  Future<Response<dynamic>> _postWithLocalFallback(
    String path, {
    required Object data,
  }) async {
    try {
      return await _dio.post<dynamic>(path, data: data);
    } on DioException catch (e) {
      final canFallback = kDebugMode &&
          AppConfig.aiKeyApiBaseUrl != 'http://localhost:6001/api';
      final status = e.response?.statusCode;
      final networkMiss = e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          status == 404;

      if (!canFallback || !networkMiss) rethrow;

      debugPrint('AI prod failed ($status), fallback to local backend');
      final local = Dio(
        BaseOptions(
          baseUrl: 'http://localhost:6001/api',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      return local.post<dynamic>(path, data: data);
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
      }
      if (e.response?.statusCode == 429) {
        return 'Закінчилась квота OpenAI на сервері. Поповніть баланс.';
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Немає з\'єднання з AI-сервером. Запустіть бекенд або перевірте інтернет.';
      }
    }
    final text = e.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '').trim();
    return text.isEmpty ? fallback : text;
  }

  static const _helperSystemPrompt =
      'You are a self-development helper, but you can answer any question. '
      'If the user asks something unrelated to self-development, respond normally '
      'without forcing that topic. Support the user in building better habits and '
      'growing, but do not lecture unsolicited. Do not accept weak conclusions as true: '
      'be an intellectual opponent when useful. '
      'Answer in the user\'s language (Ukrainian when the user writes Ukrainian). '
      'If you generate code, do not wrap it in ``` fences; put the language name on a line before the code.';
}
