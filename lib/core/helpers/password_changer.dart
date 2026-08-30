import 'package:encrypt/encrypt.dart';

class PasswordChanger {
  static const String _firstKey = 'yX7g53NL7X)xjV7#6DP+ipK5n)@9)_r!';
  static const String _secondKey = 'M%m5Vy9R(_k74t^M';

  static String encryptNewPassword(String plainText) {
    final key = Key.fromUtf8(_firstKey);
    final iv = IV.fromUtf8(_secondKey);

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }
}
