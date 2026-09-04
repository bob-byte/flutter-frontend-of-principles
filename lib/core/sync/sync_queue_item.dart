class SyncQueueItem {
  SyncQueueItem({
    this.localId,
    this.entityId,
    this.entityLocalId,
    required this.handlerType,
    required this.operation,
    this.payloadJson,
    DateTime? lastModified,
    this.isProcessing = false,
    this.isProcessed = false,
    this.retryCount = 0,
    this.nextRetryAt,
    this.lastRetryAt,
    this.processedAt,
    this.errorMessage,
    this.isFailed = false,
  }) : lastModified = lastModified ?? DateTime.now().toUtc();

  final int? localId;
  final int? entityId;
  final int? entityLocalId;
  final String handlerType;
  final String operation;
  final String? payloadJson;
  final DateTime lastModified;
  final bool isProcessing;
  final bool isProcessed;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime? lastRetryAt;
  final DateTime? processedAt;
  final String? errorMessage;
  final bool isFailed;

  SyncQueueItem copyWith({
    int? localId,
    int? entityId,
    int? entityLocalId,
    String? handlerType,
    String? operation,
    String? payloadJson,
    DateTime? lastModified,
    bool? isProcessing,
    bool? isProcessed,
    int? retryCount,
    DateTime? nextRetryAt,
    DateTime? lastRetryAt,
    DateTime? processedAt,
    String? errorMessage,
    bool? isFailed,
    bool clearErrorMessage = false,
    bool clearProcessedAt = false,
  }) {
    return SyncQueueItem(
      localId: localId ?? this.localId,
      entityId: entityId ?? this.entityId,
      entityLocalId: entityLocalId ?? this.entityLocalId,
      handlerType: handlerType ?? this.handlerType,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      lastModified: lastModified ?? this.lastModified,
      isProcessing: isProcessing ?? this.isProcessing,
      isProcessed: isProcessed ?? this.isProcessed,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      lastRetryAt: lastRetryAt ?? this.lastRetryAt,
      processedAt: clearProcessedAt ? null : (processedAt ?? this.processedAt),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      isFailed: isFailed ?? this.isFailed,
    );
  }

  Map<String, Object?> toMap() => {
    'localId': localId,
    'entityId': entityId,
    'entityLocalId': entityLocalId,
    'handlerType': handlerType,
    'operation': operation,
    'payloadJson': payloadJson,
    'lastModified': lastModified.toUtc().toIso8601String(),
    'isProcessing': isProcessing ? 1 : 0,
    'isProcessed': isProcessed ? 1 : 0,
    'retryCount': retryCount,
    'nextRetryAt': nextRetryAt?.toUtc().toIso8601String(),
    'lastRetryAt': lastRetryAt?.toUtc().toIso8601String(),
    'processedAt': processedAt?.toUtc().toIso8601String(),
    'errorMessage': errorMessage,
    'isFailed': isFailed ? 1 : 0,
  };

  factory SyncQueueItem.fromMap(Map<String, Object?> map) {
    return SyncQueueItem(
      localId: _asInt(map['localId']),
      entityId: _asInt(map['entityId']),
      entityLocalId: _asInt(map['entityLocalId']),
      handlerType: map['handlerType'] as String? ?? '',
      operation: map['operation'] as String? ?? '',
      payloadJson: map['payloadJson'] as String?,
      lastModified: _asDate(map['lastModified']) ?? DateTime.now().toUtc(),
      isProcessing: _asBool(map['isProcessing']),
      isProcessed: _asBool(map['isProcessed']),
      retryCount: _asInt(map['retryCount']) ?? 0,
      nextRetryAt: _asDate(map['nextRetryAt']),
      lastRetryAt: _asDate(map['lastRetryAt']),
      processedAt: _asDate(map['processedAt']),
      errorMessage: map['errorMessage'] as String?,
      isFailed: _asBool(map['isFailed']),
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString() == '1' || value?.toString() == 'true';
  }

  static DateTime? _asDate(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
