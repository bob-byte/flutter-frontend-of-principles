import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase Cloud Messaging config from `--dart-define` (Firebase console →
/// Project settings → Your apps). Silent sync pushes stay off until set:
///
/// `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID`,
/// `FIREBASE_ANDROID_API_KEY` + `FIREBASE_ANDROID_APP_ID`,
/// `FIREBASE_APPLE_API_KEY` + `FIREBASE_APPLE_APP_ID` (iOS + macOS).
abstract final class PushConfig {
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _appleApiKey = String.fromEnvironment('FIREBASE_APPLE_API_KEY');
  static const _appleAppId = String.fromEnvironment('FIREBASE_APPLE_APP_ID');

  static FirebaseOptions? get currentPlatform {
    if (kIsWeb || _projectId.isEmpty || _senderId.isEmpty) return null;
    if (Platform.isAndroid) return _options(_androidApiKey, _androidAppId);
    if (Platform.isIOS || Platform.isMacOS) {
      return _options(_appleApiKey, _appleAppId);
    }
    return null;
  }

  static FirebaseOptions? _options(String apiKey, String appId) {
    if (apiKey.isEmpty || appId.isEmpty) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: _senderId,
      projectId: _projectId,
    );
  }
}
