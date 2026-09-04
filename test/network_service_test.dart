import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/network_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<List<ConnectivityResult>> changes;
  late int toastCount;
  late NetworkService service;

  Future<NetworkService> startWith(
    List<ConnectivityResult> initial, {
    Duration delay = const Duration(milliseconds: 50),
  }) async {
    changes = StreamController<List<ConnectivityResult>>.broadcast();
    toastCount = 0;
    service = NetworkService(
      checkConnectivity: () async => initial,
      connectivityChanges: changes.stream,
      offlineConfirmDelay: delay,
      onOfflineToast: () => toastCount++,
    );
    await service.start();
    return service;
  }

  tearDown(() async {
    service.dispose();
    await changes.close();
  });

  test('startup none blip after wifi does not toast', () async {
    await startWith([ConnectivityResult.wifi]);
    changes.add([ConnectivityResult.none]);
    await pumpEventQueue();
    expect(service.isConnected, isFalse);
    expect(toastCount, 0);

    changes.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    service.onSplashFinished();
    expect(toastCount, 0);
  });

  test('offline after splash shows a toast once', () async {
    await startWith([ConnectivityResult.wifi]);
    changes.add([ConnectivityResult.wifi]);
    await pumpEventQueue();
    service.onSplashFinished();

    changes.add([ConnectivityResult.none]);
    await pumpEventQueue();
    expect(toastCount, 0);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(toastCount, 1);
  });

  test('still offline when splash ends shows toast after the video', () async {
    await startWith([ConnectivityResult.none]);
    changes.add([ConnectivityResult.none]);
    await pumpEventQueue();
    expect(toastCount, 0);

    service.onSplashFinished();
    expect(toastCount, 1);
  });
}
