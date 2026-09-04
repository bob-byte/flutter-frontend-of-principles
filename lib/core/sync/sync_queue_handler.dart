import 'sync_queue_item.dart';

abstract class SyncQueueHandler {
  bool canHandle(String handlerType);

  Future<void> handle(SyncQueueItem item);
}
