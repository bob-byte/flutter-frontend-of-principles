import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class SignupViewModel extends ChangeNotifier {
  SignupViewModel(this._authService);
  final AuthService _authService;

  bool _isBusy = false;
  String? _error;

  bool get isBusy => _isBusy;
  String? get error => _error;

  Future<bool> register(String email, String password, {required String genericError}) async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authService.register(email, password);
      if (!success) {
        _error = genericError;
      }
      return success;
    } catch (e) {
      _error = genericError;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
