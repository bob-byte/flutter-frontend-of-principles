import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/handlers/habit_sync_handler.dart';
import 'package:principles_app/core/sync/operation_kind.dart';
import 'package:principles_app/core/sync/sync_handler_type.dart';
import 'package:principles_app/core/sync/sync_queue_item.dart';
import 'package:principles_app/models/habit.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/habit_service.dart';

void main() {
  test('pushes save for a new habit from payload', () async {
    final habits = _FakeHabitService();
    await HabitSyncHandler(habits).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.userHabit,
        operation: OperationKind.save,
        entityId: 0,
        payloadJson: jsonEncode({'name': 'Walk', 'id': 5}),
      ),
    );

    expect(habits.pushHabitCalls, hasLength(1));
    expect(habits.pushHabitCalls.single.isNew, isTrue);
    expect(habits.pushHabitCalls.single.habit.name, 'Walk');
  });

  test('deletes remote habit by entity id', () async {
    final habits = _FakeHabitService();
    await HabitSyncHandler(habits).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.userHabit,
        operation: OperationKind.delete,
        entityId: 77,
      ),
    );
    expect(habits.deletedIds, [77]);
  });

  test('pushes archive status from payload', () async {
    final habits = _FakeHabitService();
    await HabitSyncHandler(habits).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.userHabit,
        operation: OperationKind.setArchiveStatus,
        payloadJson: jsonEncode({
          'habitId': 12,
          'isArchived': true,
          'lastModified': '2026-01-01T00:00:00.000Z',
        }),
      ),
    );

    expect(habits.archiveCalls, hasLength(1));
    expect(habits.archiveCalls.single.habitId, 12);
    expect(habits.archiveCalls.single.isArchived, isTrue);
  });

  test('throws when save payload is missing', () async {
    final habits = _FakeHabitService();
    expect(
      () => HabitSyncHandler(habits).handle(
        SyncQueueItem(
          handlerType: SyncHandlerType.userHabit,
          operation: OperationKind.save,
          entityId: 0,
        ),
      ),
      throwsStateError,
    );
  });
}

class _PushHabitCall {
  _PushHabitCall(this.habit, this.isNew);
  final Habit habit;
  final bool isNew;
}

class _ArchiveCall {
  _ArchiveCall(this.habitId, this.isArchived);
  final int habitId;
  final bool isArchived;
}

class _FakeHabitService extends HabitService {
  _FakeHabitService()
    : super(AuthService(_TokenStore(), dio: Dio()..httpClientAdapter = _Noop()));

  final pushHabitCalls = <_PushHabitCall>[];
  final deletedIds = <int>[];
  final archiveCalls = <_ArchiveCall>[];

  @override
  Future<Habit?> getHabitById(int id) async => null;

  @override
  Future<int?> pushHabit(
    Habit habit, {
    required bool isNew,
    bool enqueueOnFailure = true,
    bool awaitRemote = false,
  }) async {
    pushHabitCalls.add(_PushHabitCall(habit, isNew));
    return 100;
  }

  @override
  Future<void> deleteHabitRemote(int habitId) async {
    deletedIds.add(habitId);
  }

  @override
  Future<void> pushArchiveStatus({
    required int habitId,
    required bool isArchived,
    String? lastModified,
  }) async {
    archiveCalls.add(_ArchiveCall(habitId, isArchived));
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
    return ResponseBody.fromString('{}', 200);
  }

  @override
  void close({bool force = false}) {}
}
