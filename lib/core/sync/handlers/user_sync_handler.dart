import 'dart:convert';

import '../../network/api_client.dart';
import '../../network/api_endpoints.dart';
import '../operation_kind.dart';
import '../sync_handler_type.dart';
import '../sync_queue_handler.dart';
import '../sync_queue_item.dart';

class UserSyncHandler implements SyncQueueHandler {
  UserSyncHandler(this._apiClient);

  final ApiClient _apiClient;

  @override
  bool canHandle(String handlerType) => handlerType == SyncHandlerType.user;

  @override
  Future<void> handle(SyncQueueItem item) async {
    final payload = _decode(item.payloadJson);
    final operation = OperationKind.normalize(item.operation);
    switch (operation) {
      case OperationKind.saveUserName:
        await _apiClient.put(
          ApiEndpoints.profileName,
          data: jsonEncode(_readString(payload, 'UserName')),
        );
      case OperationKind.saveMainSlogan:
        await _apiClient.put(
          ApiEndpoints.profileMainSlogan,
          data: jsonEncode(_readString(payload, 'MainSlogan')),
        );
      case OperationKind.saveMission:
        await _apiClient.put(
          ApiEndpoints.profileMission,
          data: jsonEncode(_readString(payload, 'Mission')),
        );
      case OperationKind.saveGender:
        await _apiClient.put(
          ApiEndpoints.profileGender,
          data: jsonEncode(_readInt(payload, 'Gender')),
        );
      case OperationKind.saveHasSeenRoadGuide:
        await _apiClient.put(
          ApiEndpoints.profileRoadGuide,
          data: jsonEncode(_readBool(payload, 'HasSeenRoadGuide')),
        );
      default:
        throw UnsupportedError('Unsupported user operation: $operation');
    }
  }

  Map<String, dynamic> _decode(String? payloadJson) {
    if (payloadJson == null || payloadJson.isEmpty) {
      throw StateError('PayloadJson is null for queued user update.');
    }
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map) {
      throw StateError('Cannot deserialize user payload.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  String _readString(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    return value?.toString() ?? '';
  }

  int _readInt(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _readBool(Map<String, dynamic> payload, String key) {
    final value = payload[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }
}
