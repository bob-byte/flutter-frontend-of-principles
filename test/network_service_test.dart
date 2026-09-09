import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/network/network_service.dart';

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
}
