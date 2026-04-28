class SyncQueueItem {
  SyncQueueItem({
    this.localId,
    this.entityId,
    this.entityLocalId,
    required this.handlerType,
    required this.operation,
    this.payloadJson,
    required this.lastModified,
    this.isProcessing = false,
    this.isProcessed = false,
    this.retryCount = 0,
    this.nextRetryAt,
    this.errorMessage,
    this.isFailed = false,
  });

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
  final String? errorMessage;
  final bool isFailed;
}
