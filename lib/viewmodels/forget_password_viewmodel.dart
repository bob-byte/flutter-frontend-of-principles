import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class ForgetPasswordViewModel extends ChangeNotifier {
  final AuthService _authService;

  ForgetPasswordViewModel(this._authService);

  bool _isBusy = false;
  String? _error;

  bool get isBusy => _isBusy;
  String? get error => _error;

  Future<bool> generateCode(
    String email, {
    String? language,
    required String genericError,
    required String emailNotRegisteredError,
    required String mailServerError,
  }) async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final sent = await _authService.generateCode(email, language: language);
      if (!sent) {
        _error = genericError;
      }
      return sent;
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('EmailIsIncorrect')) {
        _error = emailNotRegisteredError;
      } else if (errorMsg.contains('Transaction failed') ||
          errorMsg.contains('500')) {
        _error = mailServerError;
      } else {
        _error = errorMsg.isNotEmpty ? errorMsg : genericError;
      }
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(
    String email,
    String newPassword, {
    required int code,
    required String genericError,
    required String wrongCodeError,
  }) async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authService.changePassword(
        email,
        newPassword,
        code: code,
      );
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
      if (_isVerificationCodeError(errorMsg)) {
        _error = wrongCodeError;
      } else {
        _error = errorMsg.isNotEmpty ? errorMsg : genericError;
      }
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  static bool _isVerificationCodeError(String errorMsg) {
    return errorMsg.contains('InvalidVerificationCode') ||
        errorMsg.contains('VerificationCodeExpired') ||
        errorMsg.contains('VerificationCodeIsRequired');
  }
}
