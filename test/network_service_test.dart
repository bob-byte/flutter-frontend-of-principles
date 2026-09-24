import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/network_service.dart';
import 'package:principles_app/core/sync/sync_run_result.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<List<ConnectivityResult>> changes;
  late NetworkService service;

  Future<NetworkService> startWith(List<ConnectivityResult> initial) async {
    changes = StreamController<List<ConnectivityResult>>.broadcast();
    service = NetworkService(
      checkConnectivity: () async => initial,
      connectivityChanges: changes.stream,
    );
    await service.start();
    return service;
  }

  tearDown(() async {
    service.dispose();
    await changes.close();
  });

  test('tracks connectivity without requiring splash', () async {
    await startWith([ConnectivityResult.wifi]);
    expect(service.isConnected, isTrue);
    expect(service.isSplashFinished, isFalse);

    changes.add([ConnectivityResult.none]);
    await pumpEventQueue();
    expect(service.isConnected, isFalse);

    changes.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(service.isConnected, isTrue);
  });

  test('first stream event only syncs state', () async {
    await startWith([ConnectivityResult.wifi]);
    changes.add([ConnectivityResult.none]);
    await pumpEventQueue();
    expect(service.isConnected, isFalse);

    changes.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(service.isConnected, isTrue);
  });

  test('onSplashFinished marks splash done once', () async {
    await startWith([ConnectivityResult.none]);
    expect(service.isSplashFinished, isFalse);

    service.onSplashFinished();
    expect(service.isSplashFinished, isTrue);

    service.onSplashFinished();
    expect(service.isSplashFinished, isTrue);
  });

  test('waitUntilSplashFinished resolves on onSplashFinished', () async {
    await startWith([ConnectivityResult.none]);
    var done = false;
    final wait = service.waitUntilSplashFinished().then((_) => done = true);
    await pumpEventQueue();
    expect(done, isFalse);

    service.onSplashFinished();
    await wait;
    expect(done, isTrue);
    await service.waitUntilSplashFinished();
  });

  test(
    'waitUntilPostSplashUiReady resolves on markPostSplashUiReady',
    () async {
      await startWith([ConnectivityResult.none]);
      var done = false;
      final wait = service.waitUntilPostSplashUiReady().then(
        (_) => done = true,
      );
      await pumpEventQueue();
      expect(done, isFalse);

      service.markPostSplashUiReady();
      await wait;
      expect(done, isTrue);
      await service.waitUntilPostSplashUiReady();
    },
  );

  test('connectivity restored is skipped until splash finishes', () async {
    var restores = 0;
    await startWith([ConnectivityResult.wifi]);
    service.onConnectivityRestored = () async {
      restores += 1;
      return const SyncRunResult(status: SyncRunStatus.succeeded);
    };

    changes.add([ConnectivityResult.none]);
    await pumpEventQueue();
    changes.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(restores, 0);

    service.onSplashFinished();
    changes.add([ConnectivityResult.none]);
    await pumpEventQueue();
    changes.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(restores, 1);
  });

  test('start is idempotent and ensureStarted waits for first check', () async {
    final connectivity = Completer<List<ConnectivityResult>>();
    changes = StreamController<List<ConnectivityResult>>.broadcast();
    service = NetworkService(
      initialConnected: false,
      checkConnectivity: () => connectivity.future,
      connectivityChanges: changes.stream,
    );

    final first = service.start();
    final second = service.start();
    expect(identical(first, second), isTrue);
    expect(service.hasStarted, isTrue);
    expect(service.isConnected, isFalse);

    var ensureDone = false;
    final ensure = service.ensureStarted().then((_) => ensureDone = true);
    await pumpEventQueue();
    expect(ensureDone, isFalse);

    connectivity.complete([ConnectivityResult.wifi]);
    await Future.wait([first, ensure]);
    expect(ensureDone, isTrue);
    expect(service.isConnected, isTrue);
  });

  test('connectivity restored callback fires after a real drop', () async {
    var restores = 0;
    await startWith([ConnectivityResult.wifi]);
    service.onSplashFinished();
    service.onConnectivityRestored = () async {
      restores += 1;
      return const SyncRunResult(status: SyncRunStatus.succeeded);
    };

    changes.add([ConnectivityResult.none]);
    await pumpEventQueue();
    changes.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(restores, 1);
  });
}
