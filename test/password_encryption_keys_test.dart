import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/config/app_config.dart';
import 'package:principles_app/core/helpers/password_changer.dart';
import 'package:principles_app/core/security/password_encryptor.dart';

void main() {
  group('password encryption keys', () {
    test('production and development key pairs differ', () {
      expect(
        AppConfig.productionPasswordEncryptionFirstKey,
        isNot(AppConfig.developmentPasswordEncryptionFirstKey),
      );
      expect(
        AppConfig.productionPasswordEncryptionSecondKey,
        isNot(AppConfig.developmentPasswordEncryptionSecondKey),
      );
    });

    test('active keys follow isLocal', () {
      if (AppConfig.isLocal) {
        expect(
          AppConfig.passwordEncryptionFirstKey,
          AppConfig.developmentPasswordEncryptionFirstKey,
        );
        expect(
          AppConfig.passwordEncryptionSecondKey,
          AppConfig.developmentPasswordEncryptionSecondKey,
        );
      } else {
        expect(
          AppConfig.passwordEncryptionFirstKey,
          AppConfig.productionPasswordEncryptionFirstKey,
        );
        expect(
          AppConfig.passwordEncryptionSecondKey,
          AppConfig.productionPasswordEncryptionSecondKey,
        );
      }
    });

    test('encrypting with production vs development keys differs', () {
      const plain = '1927Bodya';
      final production = PasswordEncryptor.encryptPassword(
        plain,
        AppConfig.productionPasswordEncryptionFirstKey,
        AppConfig.productionPasswordEncryptionSecondKey,
      );
      final development = PasswordEncryptor.encryptPassword(
        plain,
        AppConfig.developmentPasswordEncryptionFirstKey,
        AppConfig.developmentPasswordEncryptionSecondKey,
      );
      expect(production, isNot(development));
      expect(production, isNotEmpty);
      expect(development, isNotEmpty);
    });

    test('PasswordChanger uses active AppConfig keys', () {
      final viaChanger = PasswordChanger.encryptNewPassword('1927Bodya');
      final viaConfig = PasswordEncryptor.encryptPassword(
        '1927Bodya',
        AppConfig.passwordEncryptionFirstKey,
        AppConfig.passwordEncryptionSecondKey,
      );
      expect(viaChanger, viaConfig);
    });
  });
}
