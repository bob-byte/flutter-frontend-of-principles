/// Password rules aligned with MAUI [RegExps.NewPassword].
class PasswordValidation {
  PasswordValidation._();

  /// `^(?=.*[a-zа-яїієґ])(?=.*\d)[a-zа-яїієґ\d\W]{8,20}$` with IgnoreCase.
  static final RegExp newPassword = RegExp(
    r'^(?=.*[a-zа-яїієґ])(?=.*\d)[a-zа-яїієґ\d\W]{8,20}$',
    caseSensitive: false,
  );

  static bool isValidNewPassword(String? value) {
    if (value == null || value.isEmpty) return false;
    return newPassword.hasMatch(value);
  }
}
