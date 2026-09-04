import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../network/network_service.dart';
import 'sync_queue_service.dart';

/// Runs [localCall] first, then syncs to the server without blocking the UI.
///
/// When [awaitRemote] is false (default), a connected device fires [remoteCall]
/// in the background and enqueues on failure. Offline always enqueues.
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

    Future<void> enqueue() {
      return _queue.addToQueue(
        handlerType: handlerType,
        operation: operation,
        payload: payload,
        entityId: entityId,
        entityLocalId: entityLocalId,
      );
    }

    if (!_network.isConnected) {
      await enqueue();
      return null;
    }

    if (awaitRemote) {
      try {
        return await remoteCall();
      } catch (e, st) {
        debugPrint('Remote sync failed; queued ($handlerType/$operation): $e');
        debugPrint('$st');
        await enqueue();
        return null;
      }
    }

    unawaited(() async {
      try {
        await remoteCall();
      } catch (e, st) {
        debugPrint('Background sync failed; queued ($handlerType/$operation): $e');
        debugPrint('$st');
        await enqueue();
      }
    }());
    return null;
  }
}
