import 'dart:convert';

import '../../../models/ai_conversation.dart';
import '../../../services/ai_conversation_service.dart';
import '../../network/api_client.dart';
import '../../network/api_endpoints.dart';
import '../operation_kind.dart';
import '../sync_handler_type.dart';
import '../sync_queue_handler.dart';
import '../sync_queue_item.dart';

class AiConversationSyncHandler implements SyncQueueHandler {
  AiConversationSyncHandler(this._apiClient, {this.conversationService});

  final ApiClient _apiClient;
  final AiConversationService? conversationService;

  @override
  bool canHandle(String handlerType) =>
      handlerType == SyncHandlerType.aiConversation;

  @override
  Future<void> handle(SyncQueueItem item) async {
    final operation = OperationKind.normalize(item.operation);
    if (operation == OperationKind.delete) {
      final payload = _decode(item.payloadJson);
      final serverId = payload['id'] as int? ?? item.entityId ?? 0;
      final clientId = '${payload['clientId'] ?? ''}';
      if (serverId > 0) {
        await _apiClient.delete('${ApiEndpoints.aiConversations}/$serverId');
      } else if (clientId.isNotEmpty) {
        await _apiClient.delete(
          '${ApiEndpoints.aiConversations}/by-client/$clientId',
        );
      }
      return;
    }

    if (operation == OperationKind.save) {
      final conversation = await _loadConversation(item);
      final payload = conversation.toDtoJson();
      final serverId = conversation.serverId ?? item.entityId ?? 0;
      if (serverId == 0) {
        final response = await _apiClient.put(
          '${ApiEndpoints.aiConversations}/by-client/${conversation.id}',
          data: payload,
        );
        if (response.data is Map) {
          final remote = AiConversation.fromDtoJson(
            Map<String, dynamic>.from(response.data as Map),
          );
          if (remote.serverId != null) {
            await conversationService?.assignServerId(
              conversation,
              remote.serverId!,
            );
          }
        }
      } else {
        await _apiClient.put(
          '${ApiEndpoints.aiConversations}/$serverId',
          data: payload,
        );
      }
      return;
    }

    throw UnsupportedError('Unsupported AI conversation operation: $operation');
  }

  Future<AiConversation> _loadConversation(SyncQueueItem item) async {
    final payload = _decode(item.payloadJson);
    final clientId = '${payload['clientId'] ?? payload['ClientId'] ?? ''}';
    if (clientId.isNotEmpty) {
      final local = await conversationService?.getConversation(clientId);
      if (local != null) return local;
    }
    return AiConversation.fromDtoJson(payload);
  }

  Map<String, dynamic> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }
}
