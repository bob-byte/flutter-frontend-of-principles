import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class SignupViewModel extends ChangeNotifier {
  SignupViewModel(this._authService);
  final AuthService _authService;

  bool _isBusy = false;
  String? _error;

  bool get isBusy => _isBusy;
  String? get error => _error;

  /// Emails a signup verification code. The code is validated on the server
  /// when [register] is called.
  Future<bool> generateSignupCode(
    String email, {
    String? language,
    required String genericError,
    required String emailAlreadyExistsError,
  }) async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final sent = await _authService.generateSignupCode(
        email,
        language: language,
      );
      if (!sent) {
        _error = genericError;
      }
      return sent;
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('UserWithIdenticalEmailAlreadyExists')) {
        _error = emailAlreadyExistsError;
      } else if (errorMsg.contains('Transaction failed') ||
          errorMsg.contains('500')) {
        _error = genericError;
      } else {
        _error = errorMsg.isNotEmpty ? errorMsg : genericError;
      }
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required int gender,
    required int code,
    String? mission,
    String? slogan,
    required String genericError,
    required String emailAlreadyExistsError,
    required String wrongCodeError,
  }) async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _authService.register(
        name: name,
        email: email,
        password: password,
        gender: gender,
        code: code,
        mission: mission,
        slogan: slogan,
      );
      if (!success) {
        _error = genericError;
      }
      // Bootstrap sync + reminder recovery run on SyncGate in MainShell.
      return success;
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('UserWithIdenticalEmailAlreadyExists')) {
        _error = emailAlreadyExistsError;
      } else if (_isVerificationCodeError(errorMsg)) {
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
