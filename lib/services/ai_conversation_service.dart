import 'dart:async';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/storage/local_db.dart';
import '../core/sync/local_remote_executor.dart';
import '../core/sync/operation_kind.dart';
import '../core/sync/sync_handler_type.dart';
import '../models/ai_chat_message.dart';
import '../models/ai_conversation.dart';
import 'ai_conversation_storage.dart';

class AiConversationService {
  AiConversationService({
    required ApiClient apiClient,
    LocalDb? localDb,
    LocalRemoteExecutor? executor,
  }) : _apiClient = apiClient,
       _local = AiConversationStorage(localDb),
       _executor = executor;

  final ApiClient _apiClient;
  final AiConversationStorage _local;
  final LocalRemoteExecutor? _executor;

  bool get _useRemote => !AppConfig.useLocalData;

  Future<List<AiConversation>> listConversations() =>
      _local.listConversations();

  Future<AiConversation?> getConversation(String id) =>
      _local.getConversation(id);

  Future<AiConversation> saveConversation(
    AiConversation conversation, {
    bool enqueueSync = true,
  }) async {
    final now = DateTime.now().toUtc();
    final stored = conversation.copyWith(updatedAt: now, lastModified: now);
    await _local.saveConversation(stored);
    if (!_useRemote || !enqueueSync) return stored;

    Future<AiConversation> remote() async {
      final latest = await _local.getConversation(stored.id) ?? stored;
      if (latest.isDeleted) return latest;
      final payload = latest.toDtoJson();
      final serverId = latest.serverId ?? 0;
      if (serverId == 0) {
        final response = await _apiClient.put(
          '${ApiEndpoints.aiConversations}/by-client/${latest.id}',
          data: payload,
        );
        if (response.data is Map) {
          final remote = AiConversation.fromDtoJson(
            Map<String, dynamic>.from(response.data as Map),
          );
          final mapped = latest.copyWith(
            serverId: remote.serverId,
            title: remote.title.isNotEmpty ? remote.title : latest.title,
            hasAiTitle: latest.hasAiTitle || remote.title.isNotEmpty,
          );
          await _local.saveConversation(mapped);
          return mapped;
        }
        return latest;
      }

      final response = await _apiClient.put(
        '${ApiEndpoints.aiConversations}/$serverId',
        data: payload,
      );
      if (response.data is Map) {
        final remote = AiConversation.fromDtoJson(
          Map<String, dynamic>.from(response.data as Map),
        );
        final mapped = latest.copyWith(serverId: remote.serverId ?? serverId);
        await _local.saveConversation(mapped);
        return mapped;
      }
      return latest;
    }

    if (_executor != null) {
      await _executor.execute<AiConversation>(
        localCall: () async {},
        remoteCall: remote,
        handlerType: SyncHandlerType.aiConversation,
        operation: OperationKind.save,
        payload: stored.toDtoJson(),
        entityId: stored.serverId,
      );
      return stored;
    }

    unawaited(() async {
      try {
        await remote();
      } catch (_) {}
    }());
    return stored;
  }

  Future<void> deleteConversation(String id) async {
    final existing = await _local.getConversation(id, includeMessages: false);
    await _local.deleteConversation(id);
    if (!_useRemote) {
      await _local.purgeDeleted(id);
      return;
    }

    final serverId = existing?.serverId ?? 0;
    Future<void> remote() async {
      if (serverId > 0) {
        await _apiClient.delete('${ApiEndpoints.aiConversations}/$serverId');
      } else {
        await _apiClient.delete(
          '${ApiEndpoints.aiConversations}/by-client/$id',
        );
      }
      await _local.purgeDeleted(id);
    }

    if (_executor != null) {
      await _executor.execute<void>(
        localCall: () async {},
        remoteCall: remote,
        handlerType: SyncHandlerType.aiConversation,
        operation: OperationKind.delete,
        payload: {'id': serverId, 'clientId': id},
        entityId: serverId > 0 ? serverId : null,
      );
      return;
    }

    unawaited(() async {
      try {
        await remote();
      } catch (_) {}
    }());
  }

  Future<void> assignServerId(AiConversation conversation, int serverId) {
    return _local.saveConversation(conversation.copyWith(serverId: serverId));
  }

  Future<void> discardLocalConversationsAbsentFromRemote({
    required Set<String> remoteClientIds,
    required Set<int> remoteServerIds,
    Set<String> retainClientIds = const {},
    Set<int> retainServerIds = const {},
  }) async {
    for (final conversation in await _local.listConversations()) {
      if (conversation.isDeleted) continue;
      if (retainClientIds.contains(conversation.id)) continue;
      final serverId = conversation.serverId ?? 0;
      if (serverId == 0) continue;
      if (retainServerIds.contains(serverId)) continue;
      if (remoteClientIds.contains(conversation.id)) continue;
      if (remoteServerIds.contains(serverId)) continue;
      await _local.purgeDeleted(conversation.id);
    }
  }

  /// Applies a single remote delete from GET `/sync/changes` tombstones.
  Future<void> discardRemoteDeletedConversation(int serverId) async {
    if (serverId == 0) return;
    for (final conversation in await _local.listConversations()) {
      if (conversation.serverId == serverId) {
        await _local.purgeDeleted(conversation.id);
      }
    }
  }

  Future<void> mergeRemoteConversation(AiConversation remote) async {
    final existing = await _local.getConversation(remote.id);
    if (existing != null && existing.isDeleted) return;

    final localTs = existing?.lastModified ?? existing?.updatedAt;
    final remoteTs = remote.lastModified ?? remote.updatedAt;
    if (existing != null && localTs != null && localTs.isAfter(remoteTs)) {
      if (existing.serverId == null && remote.serverId != null) {
        await assignServerId(existing, remote.serverId!);
      }
      return;
    }

    final merged = remote.copyWith(
      id: existing?.id.isNotEmpty == true ? existing!.id : remote.id,
      serverId: remote.serverId ?? existing?.serverId,
      hasAiTitle: remote.hasAiTitle || (existing?.hasAiTitle ?? false),
      messages: remote.messages.isNotEmpty
          ? remote.messages
          : (existing?.messages ?? const []),
    );
    await _local.saveConversation(merged);
  }

  Future<String?> requestTitle({
    required String userMessage,
    String? assistantMessage,
  }) async {
    if (!_useRemote) return null;
    try {
      final response = await _apiClient.post(
        ApiEndpoints.aiTitle,
        data: {
          'userMessage': userMessage,
          'assistantMessage': assistantMessage,
        },
      );
      if (response.data is! Map) return null;
      final title = '${response.data['title'] ?? response.data['Title'] ?? ''}'
          .trim();
      return title.isEmpty ? null : title;
    } catch (_) {
      return null;
    }
  }

  static String placeholderTitle(String userMessage) {
    final trimmed = userMessage.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return '';
    if (trimmed.length <= 42) return trimmed;
    return '${trimmed.substring(0, 42).trimRight()}…';
  }

  static AiChatMessageModel newMessage({
    required String conversationId,
    required String role,
    required String content,
    required int sortOrder,
  }) {
    return AiChatMessageModel(
      id: AiConversationStorage.newId(),
      conversationId: conversationId,
      role: role,
      content: content,
      sortOrder: sortOrder,
      createdAt: DateTime.now().toUtc(),
    );
  }
}
