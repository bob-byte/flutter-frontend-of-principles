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

  Future<void> logout() => _secureStore.delete(_tokenKey);

  Future<String?> getToken() => _secureStore.read(_tokenKey);
}
