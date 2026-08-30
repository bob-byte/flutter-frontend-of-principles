import 'dart:async';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService;

  LoginViewModel(this._authService);

  bool _isBusy = false;
  String? _error;
  
  // Lockout logic variables
  int _failedAttempts = 0;
  bool _isTimerVisible = false;
  String _timerMessage = '';
  Timer? _lockoutTimer;
  int _secondsRemaining = 0;

  bool get isBusy => _isBusy;
  String? get error => _error;
  bool get isTimerVisible => _isTimerVisible;
  String get timerMessage => _timerMessage;
  bool get isLoginEnable => !_isBusy && !_isTimerVisible;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _startLockoutTimer(String Function(int) formatTimerMessage) {
    _isTimerVisible = true;
    _secondsRemaining = 30;
    _timerMessage = formatTimerMessage(_secondsRemaining);
    notifyListeners();

    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        _secondsRemaining--;
        _timerMessage = formatTimerMessage(_secondsRemaining);
        notifyListeners();
      } else {
        timer.cancel();
        _isTimerVisible = false;
        _failedAttempts--; // Decrease by 1 to give another chance
        notifyListeners();
      }
    });
  }

  Future<bool> login(
    String email, 
    String password, 
    {
      required String genericError,
      required String invalidCredentialsError,
      required String Function(int) formatTimerMessage,
    }
  ) async {
    if (!isLoginEnable) return false;

    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      final success = await _authService.login(email, password);
      if (!success) {
        _error = genericError;
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _startLockoutTimer(formatTimerMessage);
        }
      } else {
        _failedAttempts = 0; // Reset on success
      }
      return success;
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('InvalidEmailOrPassword')) {
        _error = invalidCredentialsError;
      } else {
        _error = errorMsg.isNotEmpty ? errorMsg : genericError;
      }

      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _startLockoutTimer(formatTimerMessage);
      }
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
