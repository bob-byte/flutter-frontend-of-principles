import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/handlers/goal_sync_handler.dart';
import 'package:principles_app/core/sync/operation_kind.dart';
import 'package:principles_app/core/sync/sync_handler_type.dart';
import 'package:principles_app/core/sync/sync_queue_item.dart';
import 'package:principles_app/models/user_goal.dart';
import 'package:principles_app/services/auth_service.dart';
import 'package:principles_app/services/goal_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> requests;
  late ApiClient apiClient;
  late _FakeGoalService goals;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({'auth_access_token': 't'});
    requests = [];
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    apiClient = ApiClient(SecureStore(), dio: dio);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(requestOptions: options, statusCode: 200, data: 88),
          );
        },
      ),
    );
    goals = _FakeGoalService(AuthService(SecureStore()));
  });

  test('posts goal save and assigns new server id', () async {
    await GoalSyncHandler(apiClient, goalService: goals).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.userGoal,
        operation: OperationKind.save,
        entityId: 0,
        payloadJson: jsonEncode({'name': 'Fitness', 'id': 0}),
      ),
    );

    expect(requests.single.method, 'POST');
    expect(requests.single.path, '${ApiEndpoints.goals}/0');
    expect(goals.assignedIds, [88]);
  });

  test('deletes goal by id from payload', () async {
    await GoalSyncHandler(apiClient, goalService: goals).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.userGoal,
        operation: OperationKind.delete,
        entityId: 14,
        payloadJson: jsonEncode({'id': 14, 'name': 'Fitness'}),
      ),
    );

    expect(requests.single.method, 'DELETE');
    expect(requests.single.path, '${ApiEndpoints.goals}/14');
  });

  test(
    'pushes archive status from payload even when local goal is archived',
    () async {
      goals.localGoal = UserGoal(
        id: 12,
        localId: 3,
        name: 'Archived',
        isArchived: true,
      );
      await GoalSyncHandler(apiClient, goalService: goals).handle(
        SyncQueueItem(
          handlerType: SyncHandlerType.userGoal,
          operation: OperationKind.setArchiveStatus,
          entityId: 12,
          entityLocalId: 3,
          payloadJson: jsonEncode({
            'goalId': 12,
            'isArchived': false,
            'lastModified': '2026-01-01T00:00:00.000Z',
          }),
        ),
      );

      expect(goals.archiveCalls, hasLength(1));
      expect(goals.archiveCalls.single.goalId, 12);
      expect(goals.archiveCalls.single.isArchived, isFalse);
    },
  );
}

class _ArchiveCall {
  _ArchiveCall(this.goalId, this.isArchived);
  final int goalId;
  final bool isArchived;
}

class _FakeGoalService extends GoalService {
  _FakeGoalService(AuthService auth) : super(auth);

  final assignedIds = <int>[];
  final archiveCalls = <_ArchiveCall>[];
  UserGoal? localGoal;

  @override
  Future<UserGoal?> getGoalByLocalId(int localId) async {
    final goal = localGoal;
    if (goal == null || goal.localId != localId) return null;
    return goal;
  }

  @override
  Future<void> assignServerId(UserGoal goal, int serverId) async {
    assignedIds.add(serverId);
  }

  @override
  Future<void> pushArchiveStatus({
    required int goalId,
    required bool isArchived,
    String? lastModified,
  }) async {
    archiveCalls.add(_ArchiveCall(goalId, isArchived));
  }
}
