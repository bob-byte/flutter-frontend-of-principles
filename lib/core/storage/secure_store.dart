import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keychain / encrypted prefs wrapper for the auth token and secrets.
///
/// Apple Keychain uniqueness is (service, account). The macOS plugin includes
/// `kSecAttrAccessible` in its exists-check, so a leftover item under a
/// different accessibility / data-protection setting makes [write] think the
/// key is missing, then [SecItemAdd] fails with errSecDuplicateItem (-25299).
/// Writes therefore purge every known Apple variant before storing.
class SecureStore {
  SecureStore()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  /// Default package options (`unlocked`) — matches historical writes.
  final FlutterSecureStorage _storage;

  static const _appleAccessibilities = <KeychainAccessibility>[
    KeychainAccessibility.unlocked,
    KeychainAccessibility.unlocked_this_device,
    KeychainAccessibility.first_unlock,
    KeychainAccessibility.first_unlock_this_device,
    KeychainAccessibility.passcode,
  ];

  Future<void> write(String key, String value) async {
    await _deleteAppleVariants(key);
    try {
      await _storage.write(key: key, value: value);
    } on PlatformException catch (e) {
      if (!_isKeychainDuplicate(e)) rethrow;
      // Last resort: wipe this plugin's items, then store once.
      await _storage.deleteAll();
      await _storage.write(key: key, value: value);
    }
  }

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> delete(String key) => _deleteAppleVariants(key);

  Future<void> _deleteAppleVariants(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}

    if (kIsWeb) return;

    for (final accessibility in _appleAccessibilities) {
      for (final useDataProtection in const [true, false]) {
        try {
          await FlutterSecureStorage(
            iOptions: IOSOptions(accessibility: accessibility),
            mOptions: MacOsOptions(
              accessibility: accessibility,
              useDataProtectionKeyChain: useDataProtection,
            ),
          ).delete(key: key);
        } catch (_) {}
      }
    }
  }

  static bool _isKeychainDuplicate(PlatformException e) {
    if (e.code == 'Unexpected security result code' && e.details == -25299) {
      return true;
    }
    if (e.message?.contains('already exists') == true) return true;
    if (e.message?.contains('-25299') == true) return true;
    final details = e.details?.toString() ?? '';
    return details.contains('-25299');
  }

  @visibleForTesting
  static bool isKeychainDuplicateItem(PlatformException e) =>
      _isKeychainDuplicate(e);
}
