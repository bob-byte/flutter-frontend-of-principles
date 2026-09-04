import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/handlers/progress_sync_handler.dart';
import 'package:principles_app/core/sync/operation_kind.dart';
import 'package:principles_app/core/sync/sync_handler_type.dart';
import 'package:principles_app/core/sync/sync_queue_item.dart';
import 'package:principles_app/core/sync/sync_queue_service.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/models/habit_record.dart';
import 'package:principles_app/models/progress_value.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/habit_service.dart';

void main() {
  test('confirmedServerHabitId ignores local-only rows', () {
    expect(confirmedServerHabitId(Habit(id: 5, name: 'Walk')), isNull);
    expect(
      confirmedServerHabitId(Habit(id: 5, name: 'Walk', serverId: 0)),
      isNull,
    );
    expect(
      confirmedServerHabitId(Habit(id: 5, name: 'Walk', serverId: 142)),
      142,
    );
  });

  test('progressDateToApi uses calendar fields, not UTC shift', () {
    expect(progressDateToApi(DateTime(2026, 9, 3, 23, 30)), '2026-09-03');
  });

  test('rewritten progress payloads are visible via getItem', () async {
    final queue = SyncQueueService(memoryItems: []);
    final id = await queue.addToQueue(
      handlerType: SyncHandlerType.progressOfHabit,
      operation: OperationKind.save,
      payload: {
        'habitId': 5,
        'date': '2026-09-03',
        'value': kProgressYesManual,
      },
    );

    await queue.rewriteProgressHabitId(fromHabitId: 5, toHabitId: 142);
    final fresh = await queue.getItem(id);
    expect(jsonDecode(fresh!.payloadJson!)['habitId'], 142);
  });

  test('queued progress with no habitId is dropped', () async {
    final habits = _FakeHabitService();
    await ProgressSyncHandler(habits).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.progressOfHabit,
        operation: OperationKind.save,
        payloadJson: jsonEncode({'habitId': 0, 'date': '2026-09-03', 'value': 2}),
      ),
    );
    expect(habits.pushCalls, isEmpty);
  });

  test('queued progress with a bad date is dropped', () async {
    final habits = _FakeHabitService();
    await ProgressSyncHandler(habits).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.progressOfHabit,
        operation: OperationKind.save,
        payloadJson: jsonEncode({'habitId': 5, 'date': 'nope', 'value': 2}),
      ),
    );
    expect(habits.pushCalls, isEmpty);
  });

  test('server 400 for queued progress is dropped instead of retried', () async {
    final habits = _FakeHabitService()..drop = true;
    await ProgressSyncHandler(habits).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.progressOfHabit,
        operation: OperationKind.save,
        payloadJson: jsonEncode({
          'habitId': 5,
          'date': '2026-09-03',
          'value': kProgressYesManual,
        }),
      ),
    );
    expect(habits.pushCalls, hasLength(1));
  });

  test('pushes queued progress with the payload habit id and date', () async {
    final habits = _FakeHabitService();
    await ProgressSyncHandler(habits).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.progressOfHabit,
        operation: OperationKind.save,
        payloadJson: jsonEncode({
          'habitId': 142,
          'date': '2026-09-03',
          'value': kProgressYesManual,
        }),
      ),
    );

    expect(habits.pushCalls, hasLength(1));
    expect(habits.pushCalls.single.habitId, 142);
    expect(habits.pushCalls.single.date, DateTime(2026, 9, 3));
    expect(habits.pushCalls.single.status, HabitStatus.completed);
  });

  test('retries when the habit is not on the server yet', () async {
    final habits = _FakeHabitService()..ok = false;
    expect(
      () => ProgressSyncHandler(habits).handle(
        SyncQueueItem(
          handlerType: SyncHandlerType.progressOfHabit,
          operation: OperationKind.save,
          payloadJson: jsonEncode({
            'habitId': 5,
            'date': '2026-09-03',
            'value': kProgressSkip,
          }),
        ),
      ),
      throwsStateError,
    );
  });
}

class _PushCall {
  _PushCall(this.habitId, this.date, this.status);

  final int habitId;
  final DateTime date;
  final HabitStatus status;
}

class _FakeHabitService extends HabitService {
  _FakeHabitService()
    : super(AuthService(_TokenStore(), dio: Dio()..httpClientAdapter = _Noop()));

  final pushCalls = <_PushCall>[];
  bool ok = true;
  bool drop = false;

  @override
  Future<bool> pushProgress(
    int habitId,
    DateTime date,
    HabitStatus status, {
    bool enqueueOnFailure = true,
  }) async {
    pushCalls.add(_PushCall(habitId, date, status));
    if (drop) {
      throw ProgressSyncDroppedException('habit missing');
    }
    return ok;
  }
}

class _TokenStore extends SecureStore {
  @override
  Future<String?> read(String key) async => 'test-token';
}

class _Noop implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
