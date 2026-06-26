import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class ForgetPasswordViewModel extends ChangeNotifier {
  final AuthService _authService;

  ForgetPasswordViewModel(this._authService);

  bool _isBusy = false;
  String? _error;

  bool get isBusy => _isBusy;
  String? get error => _error;

  Future<int?> generateCode(String email, {required String genericError}) async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final code = await _authService.generateCode(email);
      if (code == null) {
        _error = genericError;
      }
      return code;
    } catch (e) {
      _error = genericError;
      return null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(String email, String newPassword, {required String genericError}) async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authService.changePassword(email, newPassword);
      if (!success) {
        _error = genericError;
      } else {
        // Log in automatically after password change to get the token
        await _authService.login(email, newPassword);
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
