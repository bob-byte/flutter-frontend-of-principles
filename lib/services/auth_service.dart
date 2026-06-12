import '../core/storage/secure_store.dart';

class AuthService {
  AuthService(this._secureStore);

  static const _tokenKey = 'auth_access_token';
  final SecureStore _secureStore;

  Future<bool> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return false;
    await _secureStore.write(_tokenKey, 'fake_token');
    return true;
  }

  Future<bool> register(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return false;
    await _secureStore.write(_tokenKey, 'fake_token');
    return true;
  }

  Future<void> logout() => _secureStore.delete(_tokenKey);

  Future<String?> getToken() => _secureStore.read(_tokenKey);

  Future<bool> googleAuthorize() async {
    // Placeholder for Google OAuth
    await Future.delayed(const Duration(seconds: 1));
    await _secureStore.write(_tokenKey, 'fake_google_token');
    return true;
  }

  Future<bool> appleAuthorize() async {
    // Placeholder for Apple OAuth
    await Future.delayed(const Duration(seconds: 1));
    await _secureStore.write(_tokenKey, 'fake_apple_token');
    return true;
  }
}
