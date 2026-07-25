import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import 'openai_api_key_service.dart';

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
                receiveTimeout: const Duration(seconds: 90),
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
    int maxCompletionTokens = 1024,
  }) async {
    final apiKey = await _apiKeyService.resolveApiKey();
    final body = <String, dynamic>{
      'model': AppConfig.openAiModel,
      'messages': messages,
      'max_completion_tokens': maxCompletionTokens,
    };
    if (jsonObject) {
      body['response_format'] = {'type': 'json_object'};
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/completions',
      data: body,
      options: Options(headers: {'Authorization': 'Bearer $apiKey'}),
    );

    final choices = response.data?['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw StateError('OpenAI returned no choices.');
    }
    final message = (choices.first as Map)['message'] as Map?;
    final content = message?['content']?.toString().trim() ?? '';
    if (content.isEmpty) {
      throw StateError('OpenAI returned empty content.');
    }
    return content;
  }

  Stream<String> streamComplete({
    required List<Map<String, String>> messages,
    int maxCompletionTokens = 2048,
  }) async* {
    final apiKey = await _apiKeyService.resolveApiKey();
    final response = await _dio.post<ResponseBody>(
      '/chat/completions',
      data: {
        'model': AppConfig.openAiModel,
        'messages': messages,
        'stream': true,
        'max_completion_tokens': maxCompletionTokens,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Accept': 'text/event-stream',
        },
        responseType: ResponseType.stream,
      ),
    );

    final stream = response.data?.stream;
    if (stream == null) {
      throw StateError('OpenAI stream is empty.');
    }

    var buffer = '';
    await for (final chunk in stream.cast<List<int>>()) {
      buffer += utf8.decode(chunk, allowMalformed: true);
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final rawLine in lines) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith(':')) continue;
        if (!line.startsWith('data:')) continue;

        final data = line.substring(5).trim();
        if (data == '[DONE]') return;
        if (data.isEmpty) continue;

        try {
          final json = jsonDecode(data) as Map<String, dynamic>;
          final choices = json['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;
          final delta = (choices.first as Map)['delta'] as Map?;
          final content = delta?['content']?.toString();
          if (content != null && content.isNotEmpty) {
            yield content;
          }
        } catch (_) {
          // Ігноруємо биті SSE-кадри.
        }
      }
    }
  }
}
