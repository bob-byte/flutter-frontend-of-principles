import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/network_service.dart';
import 'package:principles_app/core/sync/local_remote_executor.dart';
import 'package:principles_app/core/sync/sync_queue_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('execute returns after local write without waiting on remote', () async {
    final queue = SyncQueueService(memoryItems: []);
    final executor = LocalRemoteExecutor(
      queue: queue,
      network: NetworkService(
        initialConnected: true,
        checkConnectivity: () async => const [],
        connectivityChanges: const Stream.empty(),
      ),
    );

    var localDone = false;
    var remoteStarted = false;
    var remoteFinished = false;

    final result = await executor.execute<String>(
      localCall: () async {
        localDone = true;
      },
      remoteCall: () async {
        remoteStarted = true;
        await Future<void>.delayed(const Duration(milliseconds: 200));
        remoteFinished = true;
        return 'remote';
      },
      handlerType: 'Test',
      operation: 'Save',
      payload: {'ok': true},
    );

    expect(localDone, isTrue);
    expect(result, isNull);
    expect(remoteFinished, isFalse);
    expect(await queue.getBlockingItems(), isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(remoteStarted, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(remoteFinished, isTrue);
    expect(await queue.getBlockingItems(), isEmpty);
  });

  test('execute awaits remote when awaitRemote is true', () async {
    final executor = LocalRemoteExecutor(
      queue: SyncQueueService(memoryItems: []),
      network: NetworkService(
        initialConnected: true,
        checkConnectivity: () async => const [],
        connectivityChanges: const Stream.empty(),
      ),
    );

    final result = await executor.execute<String>(
      localCall: () async {},
      remoteCall: () async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 'ok';
      },
      handlerType: 'Test',
      operation: 'Save',
      awaitRemote: true,
    );

    expect(result, 'ok');
  });

  test('execute enqueues when offline', () async {
    final queue = SyncQueueService(memoryItems: []);
    final executor = LocalRemoteExecutor(
      queue: queue,
      network: NetworkService(
        initialConnected: false,
        checkConnectivity: () async => const [],
        connectivityChanges: const Stream.empty(),
      ),
    );

    var remoteCalled = false;
    await executor.execute<void>(
      localCall: () async {},
      remoteCall: () async {
        remoteCalled = true;
      },
      handlerType: 'Test',
      operation: 'Save',
      payload: {'a': 1},
      entityLocalId: 7,
    );

    expect(remoteCalled, isFalse);
    final pending = await queue.getPendingItems();
    expect(pending, isNotEmpty);
    expect(pending.first.handlerType, 'Test');
  });
}
