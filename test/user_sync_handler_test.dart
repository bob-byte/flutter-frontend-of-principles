import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/handlers/user_sync_handler.dart';
import 'package:principles_app/core/sync/operation_kind.dart';
import 'package:principles_app/core/sync/sync_handler_type.dart';
import 'package:principles_app/core/sync/sync_queue_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> requests;
  late ApiClient apiClient;

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
            Response(requestOptions: options, statusCode: 200, data: null),
          );
        },
      ),
    );
  });

  test('puts profile name for SaveUserName', () async {
    await UserSyncHandler(apiClient).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.user,
        operation: OperationKind.saveUserName,
        payloadJson: jsonEncode({'UserName': 'Ada'}),
      ),
    );

    expect(requests.single.method, 'PUT');
    expect(requests.single.path, ApiEndpoints.profileName);
    expect(requests.single.data, jsonEncode('Ada'));
  });

  test('puts mission for SaveMission', () async {
    await UserSyncHandler(apiClient).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.user,
        operation: OperationKind.saveMission,
        payloadJson: jsonEncode({'Mission': 'Build tools'}),
      ),
    );

    expect(requests.single.path, ApiEndpoints.profileMission);
    expect(requests.single.data, jsonEncode('Build tools'));
  });

  test('puts gender for SaveGender', () async {
    await UserSyncHandler(apiClient).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.user,
        operation: OperationKind.saveGender,
        payloadJson: jsonEncode({'Gender': 1}),
      ),
    );

    expect(requests.single.method, 'PUT');
    expect(requests.single.path, ApiEndpoints.profileGender);
    expect(requests.single.data, jsonEncode(1));
  });

  test('throws for unsupported operation', () async {
    expect(
      () => UserSyncHandler(apiClient).handle(
        SyncQueueItem(
          handlerType: SyncHandlerType.user,
          operation: OperationKind.delete,
          payloadJson: jsonEncode({'UserName': 'x'}),
        ),
      ),
      throwsUnsupportedError,
    );
  });
}
