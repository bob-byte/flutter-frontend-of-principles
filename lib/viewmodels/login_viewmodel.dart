import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel(this._authService);

  final AuthService _authService;
  bool isBusy = false;
  String? error;

  Future<bool> login(String email, String password) async {
    isBusy = true;
    error = null;
    notifyListeners();
    try {
      final success = await _authService.login(email, password);
      if (!success) {
        error = 'Invalid credentials';
      }
      return success;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
