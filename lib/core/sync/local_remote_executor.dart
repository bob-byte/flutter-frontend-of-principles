import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../network/network_service.dart';
import 'sync_queue_service.dart';

/// Writes locally, durably enqueues, then tries the server without blocking UI.
///
/// The queue row is created first so bootstrap merge treats the entity as
/// pending even while a live request is in flight. Offline skips the request.
/// A failed live request stays queued for the next sync drain.
class LocalRemoteExecutor {
  LocalRemoteExecutor({
    required SyncQueueService queue,
    required NetworkService network,
  }) : _queue = queue,
       _network = network;

  final SyncQueueService _queue;
  final NetworkService _network;

  Future<T?> execute<T>({
    required Future<void> Function() localCall,
    required Future<T> Function() remoteCall,
    required String handlerType,
    required String operation,
    Object? payload,
    int? entityId,
    int? entityLocalId,
    bool awaitRemote = false,
  }) async {
    await localCall();
    if (AppConfig.useLocalData) return null;

    final queueId = await _queue.addToQueue(
      handlerType: handlerType,
      operation: operation,
      payload: payload,
      entityId: entityId,
      entityLocalId: entityLocalId,
    );

    Future<T?> runRemote() async {
      final current = await _queue.getItem(queueId);
      if (current == null || current.isProcessed) return null;
      try {
        await _queue.markAsProcessing(queueId);
        final result = await remoteCall();
        await _queue.markAsProcessed(queueId);
        return result;
      } catch (e, st) {
        debugPrint(
          'Remote sync failed; left queued ($handlerType/$operation): $e',
        );
        debugPrint('$st');
        await _queue.releaseProcessing(queueId);
        return null;
      }
    }

    if (!_network.isConnected) {
      return null;
    }

    if (awaitRemote) {
      return runRemote();
    }

    unawaited(runRemote());
    return null;
  }
}
