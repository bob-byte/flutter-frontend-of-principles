import '../config/app_config.dart';
import '../security/password_encryptor.dart';

/// Encrypts passwords for `/api/account/*` using the same AES-CBC scheme as MAUI.
///
/// Keys follow [AppConfig.isLocal]: Development when `API_ENV=local` /
/// `LOCALDEBUG=true`, otherwise production.
class PasswordChanger {
  static String encryptNewPassword(String plainText) {
    return PasswordEncryptor.encryptPassword(
      plainText,
      AppConfig.passwordEncryptionFirstKey,
      AppConfig.passwordEncryptionSecondKey,
    );
  }
}
