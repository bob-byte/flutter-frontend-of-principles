import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class SignupViewModel extends ChangeNotifier {
  SignupViewModel(this._authService);
  final AuthService _authService;

  bool _isBusy = false;
  String? _error;

  bool get isBusy => _isBusy;
  String? get error => _error;

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required int gender,
    String? mission,
    String? slogan,
    required String genericError,
    required String emailAlreadyExistsError,
  }) async {
    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      // Pass all fields to auth service
      final success = await _authService.register(
        name: name,
        email: email,
        password: password,
        gender: gender,
        mission: mission,
        slogan: slogan,
      );
      if (!success) {
        _error = genericError;
      }
      return success;
    } catch (e) {
      // Extract specific backend error if it's an Exception
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('UserWithIdenticalEmailAlreadyExists')) {
        _error = emailAlreadyExistsError;
      } else {
        _error = errorMsg.isNotEmpty ? errorMsg : genericError;
      }
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
