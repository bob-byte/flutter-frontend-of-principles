import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/api_client.dart';
import 'package:principles_app/core/network/api_endpoints.dart';
import 'package:principles_app/core/storage/secure_store.dart';
import 'package:principles_app/core/sync/handlers/reminder_sync_handler.dart';
import 'package:principles_app/core/sync/operation_kind.dart';
import 'package:principles_app/core/sync/sync_handler_type.dart';
import 'package:principles_app/core/sync/sync_queue_item.dart';
import 'package:principles_app/models/reminder.dart';
import 'package:principles_app/services/reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> requests;
  late ApiClient apiClient;
  late _FakeReminderService reminders;

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
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'id': 4, 'userNotificationRequestId': 1},
            ),
          );
        },
      ),
    );
    reminders = _FakeReminderService();
  });

  test('posts reminder save and applies server ids', () async {
    await ReminderSyncHandler(apiClient, reminderService: reminders).handle(
      SyncQueueItem(
        handlerType: SyncHandlerType.reminder,
        operation: OperationKind.save,
        entityLocalId: 2,
        payloadJson: jsonEncode({
          'localId': 2,
          'title': 'Report',
          'description': 'Daily',
          'time': '20:00',
          'isEnabled': true,
        }),
      ),
    );

    expect(requests.single.method, 'POST');
    expect(requests.single.path, '${ApiEndpoints.habitsReportReminder}/0');
    expect(reminders.appliedIds, [4]);
  });

  test('throws for unsupported operation', () async {
    expect(
      () => ReminderSyncHandler(apiClient, reminderService: reminders).handle(
        SyncQueueItem(
          handlerType: SyncHandlerType.reminder,
          operation: OperationKind.delete,
          payloadJson: jsonEncode({'title': 'x'}),
        ),
      ),
      throwsUnsupportedError,
    );
  });
}

class _FakeReminderService extends ReminderService {
  _FakeReminderService() : super(forceLocalOnly: true);

  final appliedIds = <int>[];

  @override
  Future<Reminder?> getByLocalId(int localId) async => null;

  @override
  Future<void> applyServerIds({
    int? localId,
    required int id,
    required int userNotificationRequestId,
  }) async {
    appliedIds.add(id);
  }
}
