import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as aes;

/// AES-шифрування пароля як у MAUI `PasswordChanger.EncryptNewPassword`.
class PasswordEncryptor {
  const PasswordEncryptor._();

  static String encryptPassword(
    String plainText,
    String firstKey,
    String secondKey,
  ) {
    final key = aes.Key(Uint8List.fromList(utf8.encode(firstKey)));
    final iv = aes.IV(Uint8List.fromList(utf8.encode(secondKey)));
    final encrypter = aes.Encrypter(aes.AES(key, mode: aes.AESMode.cbc));
    return encrypter.encrypt(plainText, iv: iv).base64;
  }
}
