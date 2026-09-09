import 'dart:convert';

import 'sync_handler_type.dart';
import 'sync_queue_item.dart';

/// In-memory index of unprocessed queue items so merge can avoid N+1 scans.
class PendingSyncIndex {
  PendingSyncIndex(List<SyncQueueItem> items) {
    for (final item in items) {
      switch (item.handlerType) {
        case SyncHandlerType.user:
          hasUser = true;
        case SyncHandlerType.reminder:
          hasReminder = true;
        case SyncHandlerType.userGoal:
          _add(_goalIds, item.entityId);
          _add(_goalLocalIds, item.entityLocalId);
        case SyncHandlerType.userHabit:
          _add(_habitIds, item.entityId);
          _add(_habitLocalIds, item.entityLocalId);
          _add(_habitIds, _archivePayloadHabitId(item));
        case SyncHandlerType.progressOfHabit:
          _indexProgress(item);
        case SyncHandlerType.task:
          _indexTask(item);
        case SyncHandlerType.aiConversation:
          _indexConversation(item);
      }
    }
  }

  bool hasUser = false;
  bool hasReminder = false;

  final Set<int> _goalIds = {};
  final Set<int> _goalLocalIds = {};
  final Set<int> _habitIds = {};
  final Set<int> _habitLocalIds = {};
  final Set<int> _progressHabitIds = {};
  final Set<String> _progressKeys = {};
  final Set<int> _taskIds = {};
  final Set<int> _conversationIds = {};
  final Set<String> pendingConversationClientIds = {};

  final Set<int> pendingTaskDeletes = {};
  final Set<int> pendingTaskSaves = {};
  final Set<int> pendingConversationDeletes = {};
  final Set<int> pendingConversationSaves = {};

  bool pendingGoal({int? serverId, int? localId}) {
    return _matches(_goalIds, serverId) || _matches(_goalLocalIds, localId);
  }

  bool pendingHabit({int? serverId, int? localId}) {
    return _matches(_habitIds, serverId) || _matches(_habitLocalIds, localId);
  }

  bool pendingTask(int serverId) => _matches(_taskIds, serverId);

  bool pendingConversation({int? serverId, String? clientId}) {
    if (_matches(_conversationIds, serverId)) return true;
    return clientId != null &&
        clientId.isNotEmpty &&
        pendingConversationClientIds.contains(clientId);
  }

  bool pendingProgress({
    required int habitId,
    required String dateKey,
    int? recordId,
  }) {
    if (_progressKeys.contains('$habitId|$dateKey')) return true;
    if (recordId != null &&
        recordId != 0 &&
        _progressKeys.contains('record:$recordId')) {
      return true;
    }
    return false;
  }

  bool habitHasPendingProgress(int serverId, int? localId) {
    if (_progressHabitIds.contains(serverId)) return true;
    return localId != null && _progressHabitIds.contains(localId);
  }

  void _indexProgress(SyncQueueItem item) {
    if (item.entityId != null && item.entityId != 0) {
      _progressKeys.add('record:${item.entityId}');
    }
    if (item.entityLocalId != null && item.entityLocalId != 0) {
      _progressKeys.add('record:${item.entityLocalId}');
    }
    final payload = _payloadMap(item);
    if (payload == null) return;
    final habitId = _asInt(payload['habitId'] ?? payload['HabitId']);
    final dateKey = _dateKey(payload['date'] ?? payload['Date']);
    if (habitId == null || dateKey == null) return;
    _progressHabitIds.add(habitId);
    _progressKeys.add('$habitId|$dateKey');
  }

  void _indexTask(SyncQueueItem item) {
    final id = item.entityId;
    if (id == null || id == 0) return;
    _taskIds.add(id);
    if (item.operation.toLowerCase() == 'delete') {
      pendingTaskDeletes.add(id);
    } else {
      pendingTaskSaves.add(id);
    }
  }

  void _indexConversation(SyncQueueItem item) {
    final id = item.entityId;
    if (id != null && id != 0) {
      _conversationIds.add(id);
      if (item.operation.toLowerCase() == 'delete') {
        pendingConversationDeletes.add(id);
      } else {
        pendingConversationSaves.add(id);
      }
    }
    final payload = _payloadMap(item);
    final clientId = payload?['clientId']?.toString();
    if (clientId != null && clientId.isNotEmpty) {
      pendingConversationClientIds.add(clientId);
    }
  }

  static void _add(Set<int> ids, int? id) {
    if (id != null && id != 0) ids.add(id);
  }

  static bool _matches(Set<int> ids, int? id) {
    return id != null && id != 0 && ids.contains(id);
  }

  static int? _archivePayloadHabitId(SyncQueueItem item) {
    final payload = _payloadMap(item);
    if (payload == null) return null;
    return _asInt(payload['habitId'] ?? payload['HabitId']);
  }

  static Map<String, dynamic>? _payloadMap(SyncQueueItem item) {
    final raw = item.payloadJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _dateKey(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) {
      return _ymd(raw.year, raw.month, raw.day);
    }
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})',
    ).firstMatch(raw.toString().trim());
    if (match == null) return null;
    return '${match.group(1)}-${match.group(2)}-${match.group(3)}';
  }

  static String _ymd(int year, int month, int day) {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
