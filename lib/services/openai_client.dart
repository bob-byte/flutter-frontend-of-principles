import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import 'openai_api_key_service.dart';

/// Помилка OpenAI з текстом, придатним для показу користувачу.
class OpenAiException implements Exception {
  OpenAiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Тонкий клієнт OpenAI Chat Completions (`gpt-5-nano` за замовчуванням).
class OpenAiClient {
  OpenAiClient({
    required OpenAiApiKeyService apiKeyService,
    Dio? dio,
  })  : _apiKeyService = apiKeyService,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.openai.com/v1',
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 120),
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  final OpenAiApiKeyService _apiKeyService;
  final Dio _dio;

  Future<String> complete({
    required List<Map<String, String>> messages,
    bool jsonObject = false,
    int maxCompletionTokens = 4096,
  }) async {
    final apiKey = await _apiKeyService.resolveApiKey();
    final body = <String, dynamic>{
      'model': AppConfig.openAiModel,
      'messages': messages,
      'max_completion_tokens': maxCompletionTokens,
      // Мінімальне «мислення», щоб лишився бюджет на видиму відповідь.
      'reasoning_effort': 'minimal',
    };
    if (jsonObject) {
      body['response_format'] = {'type': 'json_object'};
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/chat/completions',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
      );
      return _contentFromResponse(response.data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Stream<String> streamComplete({
    required List<Map<String, String>> messages,
    int maxCompletionTokens = 4096,
  }) async* {
    final apiKey = await _apiKeyService.resolveApiKey();
    late final Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        '/chat/completions',
        data: {
          'model': AppConfig.openAiModel,
          'messages': messages,
          'stream': true,
          'max_completion_tokens': maxCompletionTokens,
          'reasoning_effort': 'minimal',
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Accept': 'text/event-stream',
          },
          responseType: ResponseType.stream,
        ),
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    }

    final stream = response.data?.stream;
    if (stream == null) {
      throw OpenAiException('OpenAI stream is empty.');
    }

    var buffer = '';
    var yielded = false;
    await for (final chunk in stream) {
      buffer += utf8.decode(chunk, allowMalformed: true);
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith(':')) continue;
        if (!line.startsWith('data:')) continue;

        final data = line.substring(5).trim();
        if (data == '[DONE]') {
          if (!yielded) {
            throw OpenAiException(
              'Модель повернула порожню відповідь. Спробуйте ще раз.',
            );
          }
          return;
        }
        if (data.isEmpty) continue;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          if (json['error'] != null) {
            throw OpenAiException(_messageFromApiError(json['error']));
          }
          final choices = json['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;
          final delta = (choices.first as Map)['delta'] as Map?;
          final content = delta?['content']?.toString();
          if (content != null && content.isNotEmpty) {
            yielded = true;
            yield content;
          }
        } on OpenAiException {
          rethrow;
        } catch (_) {
          // Ігноруємо биті SSE-кадри.
        }
      }
    }
  }

  String _contentFromResponse(Map<String, dynamic>? data) {
    if (data == null) {
      throw OpenAiException('OpenAI returned an empty response.');
    }
    if (data['error'] != null) {
      throw OpenAiException(_messageFromApiError(data['error']));
    }

    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw OpenAiException('OpenAI returned no choices.');
    }

    final first = choices.first as Map;
    final message = first['message'] as Map?;
    final content = message?['content']?.toString().trim() ?? '';
    final finish = first['finish_reason']?.toString();

    if (content.isEmpty) {
      debugPrint('OpenAI empty content. finish_reason=$finish usage=${data['usage']}');
      throw OpenAiException(
        finish == 'length'
            ? 'Модель не встигла сформувати відповідь. Спробуйте коротший запит.'
            : 'OpenAI повернув порожню відповідь. Перевірте квоту API.',
      );
    }
    return content;
  }

  OpenAiException _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? apiMessage;
    if (data is Map) {
      apiMessage = _messageFromApiError(data['error'] ?? data);
    } else if (data is String && data.trim().isNotEmpty) {
      apiMessage = data.trim();
    }

    debugPrint('OpenAI DioException status=$status type=${e.type} msg=$apiMessage');

    if (status == 401) {
      return OpenAiException(
        'Невірний OpenAI API ключ. Оновіть ключ у налаштуваннях.',
        statusCode: status,
      );
    }
    if (status == 429 || (apiMessage ?? '').toLowerCase().contains('quota')) {
      return OpenAiException(
        'Закінчилась квота OpenAI. Поповніть баланс на platform.openai.com.',
        statusCode: status,
      );
    }
    if (status == 404) {
      return OpenAiException(
        'Модель ${AppConfig.openAiModel} недоступна для цього ключа.',
        statusCode: status,
      );
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      if (kIsWeb) {
        return OpenAiException(
          'Браузер блокує прямий виклик OpenAI (CORS). '
          'Запустіть додаток на Android/Windows або через API-бекенд.',
        );
      }
      return OpenAiException('Немає з\'єднання з OpenAI. Перевірте інтернет.');
    }

    return OpenAiException(
      apiMessage ?? 'Помилка OpenAI (${status ?? e.type.name}).',
      statusCode: status,
    );
  }

  String _messageFromApiError(Object? error) {
    if (error is Map) {
      final message = error['message']?.toString();
      final code = error['code']?.toString();
      if (code == 'insufficient_quota') {
        return 'Закінчилась квота OpenAI. Поповніть баланс на platform.openai.com.';
      }
      if (message != null && message.trim().isNotEmpty) return message.trim();
    }
    return error?.toString() ?? 'Unknown OpenAI error';
  }
}
