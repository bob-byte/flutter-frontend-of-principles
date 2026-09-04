import 'dart:convert';

import '../../../models/user_goal.dart';
import '../../../services/goal_service.dart';
import '../../network/api_client.dart';
import '../../network/api_endpoints.dart';
import '../operation_kind.dart';
import '../sync_handler_type.dart';
import '../sync_queue_handler.dart';
import '../sync_queue_item.dart';

class GoalSyncHandler implements SyncQueueHandler {
  GoalSyncHandler(this._apiClient, {this.goalService});

  final ApiClient _apiClient;
  final GoalService? goalService;

  @override
  bool canHandle(String handlerType) => handlerType == SyncHandlerType.userGoal;

  @override
  Future<void> handle(SyncQueueItem item) async {
    final operation = OperationKind.normalize(item.operation);
    final goal = await _loadGoal(item);

    if (operation == OperationKind.save) {
      final serverId = goal.id ?? 0;
      final response = await _apiClient.post(
        '${ApiEndpoints.goals}/$serverId',
        data: {
          'id': serverId,
          'name': goal.name,
          'isCompleted': goal.isCompleted,
        },
      );
      final newId = _readId(response.data);
      if (newId != null && newId != goal.id) {
        await goalService?.assignServerId(goal, newId);
      }
      return;
    }

    if (operation == OperationKind.delete) {
      final id = goal.id ?? item.entityId ?? 0;
      if (id != 0) {
        await _apiClient.delete('${ApiEndpoints.goals}/$id');
      }
      return;
    }

    throw UnsupportedError('Unsupported goal operation: $operation');
  }

  Future<UserGoal> _loadGoal(SyncQueueItem item) async {
    if (item.entityLocalId != null && item.entityLocalId != 0) {
      final local = await goalService?.getGoalByLocalId(item.entityLocalId!);
      if (local != null) return local;
    }
    if (item.payloadJson == null) {
      throw StateError('PayloadJson is null for GoalSyncHandler queue item.');
    }
    final decoded = jsonDecode(item.payloadJson!);
    if (decoded is! Map) {
      throw StateError('Cannot deserialize queued UserGoal.');
    }
    final map = Map<String, dynamic>.from(decoded);
    return UserGoal.fromJson({
      ...map,
      'localId': map['localId'] ?? item.entityLocalId,
      'id': map['id'] ?? item.entityId,
      'lastModified':
          map['lastModified'] ?? item.lastModified?.toIso8601String(),
    });
  }

  int? _readId(dynamic data) {
    if (data is num) return data.toInt();
    if (data is Map) {
      return (data['id'] ?? data['Id']) is num
          ? (data['id'] ?? data['Id'] as num).toInt()
          : int.tryParse('${data['id'] ?? data['Id']}');
    }
    return int.tryParse('$data');
  }
}
