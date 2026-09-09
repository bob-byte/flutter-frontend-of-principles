import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class ForgetPasswordViewModel extends ChangeNotifier {
  final AuthService _authService;

  ForgetPasswordViewModel(this._authService);

  bool _isBusy = false;
  String? _error;

  bool get isBusy => _isBusy;
  String? get error => _error;

  Future<int?> generateCode(
    String email, {
    required String genericError,
  }) async {
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
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('EmailIsIncorrect')) {
        _error = 'Такого користувача не знайдено (Email не зареєстровано).';
      } else if (errorMsg.contains('Transaction failed') ||
          errorMsg.contains('500')) {
        _error =
            'Помилка поштового сервера на бекенді. Зверніться до адміністратора.';
      } else {
        _error = errorMsg.isNotEmpty ? errorMsg : genericError;
      }
      return null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(
    String email,
    String newPassword, {
    required String genericError,
  }) async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authService.changePassword(email, newPassword);
      if (!success) {
        _error = genericError;
      } else {
        // Log in automatically after password change to get the token.
        // Bootstrap sync + reminder recovery run on SyncGate in MainShell.
        await _authService.login(email, newPassword);
      }
      return success;
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      _error = errorMsg.isNotEmpty ? errorMsg : genericError;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
