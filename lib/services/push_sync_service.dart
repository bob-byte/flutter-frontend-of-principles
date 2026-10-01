import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/push/device_identity.dart';
import '../core/push/push_config.dart';
import '../core/push/remote_delete_reminders.dart';
import '../core/push/sync_push_message.dart';

typedef SyncPushHandler = Future<void> Function(SyncPushMessage push);

/// Android runs background pushes in a separate isolate; it forwards them to
/// the live app isolate through this port when the app process is alive.
const kSyncPushPortName = 'principles_sync_push';

@pragma('vm:entry-point')
Future<void> onSyncPushInBackground(RemoteMessage message) async {
  final push = SyncPushMessage.tryParse(message.data);
  if (push == null) return;
  await PushSyncService.dispatch(push);
}

/// Silent FCM/APNs pushes from the backend that wake the app to sync when
/// another device changes or deletes tasks/habits.
class PushSyncService {
  PushSyncService({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  StreamSubscription<RemoteMessage>? _onMessage;
  StreamSubscription<String>? _onTokenRefresh;

  static bool _ready = false;
  static SyncPushHandler? _handler;
  static ReceivePort? _port;

  static bool get isReady => _ready;

  static bool get _isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  /// Call from `main()` before `runApp` so a push that cold-starts the app in
  /// the background finds its handler.
  static Future<void> initialize() async {
    if (_ready || !_isSupportedPlatform || AppConfig.useLocalData) return;
    final options = PushConfig.currentPlatform;
    if (options == null) return;
    try {
      await Firebase.initializeApp(options: options);
      FirebaseMessaging.onBackgroundMessage(onSyncPushInBackground);
      _ready = true;
    } catch (e) {
      debugPrint('Push init failed: $e');
    }
  }

  /// Routes [push] to the signed-in shell if it runs in this isolate (iOS,
  /// Android foreground), else to the live app isolate, else cancels the
  /// deleted rows' reminders headlessly (app not running — no SQLite here).
  static Future<void> dispatch(SyncPushMessage push) async {
    final handler = _handler;
    if (handler != null) return handler(push);
    final port = IsolateNameServer.lookupPortByName(kSyncPushPortName);
    if (port != null) {
      port.send(push.toData());
      return;
    }
    DartPluginRegistrant.ensureInitialized();
    await cancelRemoteDeletedReminders(
      plugin: FlutterLocalNotificationsPlugin(),
      taskIds: push.deletedTaskIds,
      habitIds: push.deletedHabitIds,
    );
  }

  /// Signed-in shell is up: deliver pushes to [handler] and register the
  /// device token for this account.
  void attach(SyncPushHandler handler) {
    if (!_ready) return;
    _handler = handler;
    _port?.close();
    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(kSyncPushPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, kSyncPushPortName);
    port.listen((data) {
      if (data is! Map) return;
      final push = SyncPushMessage.tryParse(Map<String, dynamic>.from(data));
      if (push != null) unawaited(_handler?.call(push));
    });
    _port = port;
    _onMessage ??= FirebaseMessaging.onMessage.listen((message) {
      final push = SyncPushMessage.tryParse(message.data);
      if (push != null) unawaited(_handler?.call(push));
    });
    _onTokenRefresh ??= FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => unawaited(_register(token)),
    );
    unawaited(registerDevice());
  }

  void detach() {
    _handler = null;
    IsolateNameServer.removePortNameMapping(kSyncPushPortName);
    _port?.close();
    _port = null;
    unawaited(_onMessage?.cancel());
    _onMessage = null;
    unawaited(_onTokenRefresh?.cancel());
    _onTokenRefresh = null;
  }

  Future<void> registerDevice() async {
    if (!_ready) return;
    final token = await _token();
    if (token != null) await _register(token);
  }

  /// Logout: stop sync pushes for this account on this device.
  Future<void> unregisterDevice() async {
    if (!_ready) return;
    detach();
    try {
      final deviceId = await DeviceIdentity.id();
      await _apiClient.delete('${ApiEndpoints.devicePushToken}/$deviceId');
    } catch (e) {
      debugPrint('Unregister push token failed: $e');
    }
  }

  Future<String?> _token() async {
    final messaging = FirebaseMessaging.instance;
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        // FCM needs the APNs token first; it can lag app start by seconds.
        for (var i = 0; i < 10; i++) {
          if (await messaging.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(seconds: 3));
        }
      }
      return await messaging.getToken();
    } catch (e) {
      debugPrint('Get push token failed: $e');
      return null;
    }
  }

  Future<void> _register(String token) async {
    try {
      await _apiClient.put(
        ApiEndpoints.devicePushToken,
        data: {
          'deviceId': await DeviceIdentity.id(),
          'token': token,
          'platform': Platform.operatingSystem,
        },
      );
    } catch (e) {
      debugPrint('Register push token failed: $e');
    }
  }
}
