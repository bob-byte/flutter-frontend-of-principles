import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/ai_task_draft.dart';

const _sseDone = Object();

/// AI via the app backend. The OpenAI key stays on the server.
class AiChatService {
  AiChatService(this._apiClient);

  static const _aiTimeout = Duration(seconds: 120);

  final ApiClient _apiClient;
  final List<Map<String, String>> _messages = [];

  Stream<String> streamAnswer(
    String prompt, {
    required String fallbackResponse,
    required String errorMessage,
  }) async* {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return;

    _messages.add({'role': 'user', 'content': trimmed});

    final cancelToken = CancelToken();
    final assembled = StringBuffer();
    try {
      final response = await _apiClient.postStream(
        ApiEndpoints.aiChat,
        data: {'messages': List<Map<String, String>>.from(_messages)},
        receiveTimeout: _aiTimeout,
        cancelToken: cancelToken,
      );

      await for (final chunk in chunksFromResponse(response.data)) {
        if (chunk.isEmpty) continue;
        assembled.write(chunk);
        yield chunk;
      }

      final content = assembled.toString();
      if (content.trim().isEmpty) {
        yield fallbackResponse;
        _messages.add({'role': 'assistant', 'content': fallbackResponse});
      } else {
        _messages.add({'role': 'assistant', 'content': content});
      }
    } catch (e) {
      if (assembled.isEmpty) {
        if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
          _messages.removeLast();
        }
        yield await _errorText(e, errorMessage);
      } else {
        _messages.add({'role': 'assistant', 'content': assembled.toString()});
      }
    } finally {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('stream closed');
      }
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
      final response = await _apiClient.post(
        ApiEndpoints.aiParseTask,
        data: {'prompt': trimmed},
        receiveTimeout: _aiTimeout,
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

  Future<String> _errorText(Object e, String fallback) async {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is ResponseBody) {
        try {
          final text = await utf8.decoder.bind(data.stream).join();
          return _userFacingError(
            DioException(
              requestOptions: e.requestOptions,
              response: Response(
                requestOptions: e.requestOptions,
                statusCode: e.response?.statusCode,
                data: _tryDecodeJson(text) ?? text,
              ),
              type: e.type,
              message: e.message,
              error: e.error,
            ),
            fallback,
          );
        } catch (_) {
          // Fall through to status-code mapping.
        }
      }
    }
    return _userFacingError(e, fallback);
  }

  String _userFacingError(Object e, String fallback) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final err = data['error'] ?? data['Error'] ?? data['title'];
        if (err != null && err.toString().trim().isNotEmpty) {
          return err.toString().trim();
        }
      } else if (data is String && data.trim().isNotEmpty) {
        return data.trim();
      }
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return 'Увійдіть в акаунт, щоб користуватися AI.';
      }
      if (e.response?.statusCode == 429) {
        return 'Закінчилась квота OpenAI на сервері. Поповніть баланс.';
      }
      if (e.response?.statusCode == 503) {
        return 'AI ще не налаштований на сервері.';
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'Немає з\'єднання з AI-сервером. Запустіть бекенд або перевірте інтернет.';
      }
    }
    final text = e
        .toString()
        .replaceFirst(RegExp(r'^Bad state:\s*'), '')
        .trim();
    return text.isEmpty ? fallback : text;
  }
}

@visibleForTesting
Stream<String> chunksFromResponse(Object? data) async* {
  if (data is Map) {
    final content = _contentFromMap(data);
    if (content != null && content.isNotEmpty) {
      yield content;
    }
    return;
  }

  if (data is String) {
    yield* _readSseChunks(Stream<List<int>>.value(utf8.encode(data)));
    return;
  }

  if (data is ResponseBody) {
    yield* _readSseChunks(data.stream);
    return;
  }

  if (data is Stream) {
    yield* _readSseChunks(data.cast<List<int>>());
  }
}

Stream<String> _readSseChunks(Stream<List<int>> byteStream) async* {
  var leftover = '';
  await for (final piece in utf8.decoder.bind(byteStream)) {
    leftover += piece.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    while (true) {
      final separator = leftover.indexOf('\n\n');
      if (separator < 0) {
        break;
      }
      final rawEvent = leftover.substring(0, separator);
      leftover = leftover.substring(separator + 2);
      final parsed = _parseSseEvent(rawEvent);
      if (identical(parsed, _sseDone)) {
        return;
      }
      if (parsed is String && parsed.isNotEmpty) {
        yield parsed;
      }
    }
  }

  final tail = leftover.trim();
  if (tail.isEmpty) {
    return;
  }
  final parsed = _parseSseEvent(tail);
  if (identical(parsed, _sseDone)) {
    return;
  }
  if (parsed is String && parsed.isNotEmpty) {
    yield parsed;
  }
}

Object? _parseSseEvent(String event) {
  final data = event
      .split('\n')
      .where((line) => line.startsWith('data:'))
      .map((line) => line.substring(5).trim())
      .join('\n');

  if (data.isEmpty) {
    return _contentFromJson(event);
  }
  if (data == '[DONE]') {
    return _sseDone;
  }
  return _contentFromJson(data);
}

String? _contentFromJson(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final decoded = _tryDecodeJson(trimmed);
  if (decoded is! Map) {
    return null;
  }
  return _contentFromMap(decoded);
}

String? _contentFromMap(Map<dynamic, dynamic> decoded) {
  final err = decoded['error'] ?? decoded['Error'];
  if (err != null) {
    final message = err is Map
        ? (err['message'] ?? err['Message'] ?? err).toString()
        : err.toString();
    if (message.trim().isNotEmpty) {
      throw StateError(message.trim());
    }
  }

  final content = decoded['content'] ?? decoded['Content'];
  if (content is String) {
    return content;
  }
  return content?.toString();
}

Object? _tryDecodeJson(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}
