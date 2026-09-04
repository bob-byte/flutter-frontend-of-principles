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
}

class _FakeGoalService extends GoalService {
  _FakeGoalService(AuthService auth) : super(auth);

  final assignedIds = <int>[];

  @override
  Future<UserGoal?> getGoalByLocalId(int localId) async => null;

  @override
  Future<void> assignServerId(UserGoal goal, int serverId) async {
    assignedIds.add(serverId);
  }
}
