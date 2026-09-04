import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/habit_service.dart';

void main() {
  test(
    'concurrent backend sync requests share one in-flight operation',
    () async {
      final adapter = _DelayedHabitsAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final authService = AuthService(_TokenStore(), dio: dio);
      final habitService = HabitService(authService);

      final first = habitService.syncFromBackend();
      final second = habitService.syncFromBackend();

      expect(identical(first, second), isTrue);
      await adapter.requestStarted;
      expect(adapter.requestCount, 1);

      adapter.release();
      await Future.wait([first, second]);

      await habitService.syncFromBackend();
      expect(adapter.requestCount, 2);
    },
  );

  test('habit deletion removes the backend habit', () async {
    final adapter = _RecordingAdapter(statusCode: 200);
    final dio = Dio()..httpClientAdapter = adapter;
    final habitService = HabitService(AuthService(_TokenStore(), dio: dio));

    expect(await habitService.deleteHabit(104), isTrue);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.method, 'DELETE');
    expect(Uri.parse(adapter.requests.single.path).path, '/api/habits/104');
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer test-token',
    );
  });

  test('deleting an already absent backend habit still succeeds', () async {
    final adapter = _RecordingAdapter(statusCode: 404);
    final dio = Dio()..httpClientAdapter = adapter;
    final habitService = HabitService(AuthService(_TokenStore(), dio: dio));

    expect(await habitService.deleteHabit(104), isTrue);
  });
}

class _TokenStore extends SecureStore {
  @override
  Future<String?> read(String key) async => 'test-token';
}

class _DelayedHabitsAdapter implements HttpClientAdapter {
  final Completer<void> _firstRequest = Completer<void>();
  final Completer<void> _requestStarted = Completer<void>();
  int requestCount = 0;

  Future<void> get requestStarted => _requestStarted.future;

  void release() => _firstRequest.complete();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    if (!_requestStarted.isCompleted) {
      _requestStarted.complete();
    }
    await _firstRequest.future;
    return ResponseBody.fromString(
      '[]',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.statusCode});

  final int statusCode;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
