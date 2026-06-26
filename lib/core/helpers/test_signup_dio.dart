import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';
import 'dart:convert';

void main() async {
  const _firstKey = 'yX7g53NL7X)xjV7#6DP+ipK5n)@9)_r!';
  const _secondKey = 'M%m5Vy9R(_k74t^M';

  final key = Key.fromUtf8(_firstKey);
  final iv = IV.fromUtf8(_secondKey);
  final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
  final encrypted = encrypter.encrypt('MyPassword123!', iv: iv);

  final dio = Dio();
  try {
    final response = await dio.post(
      'https://principles-server.ckwavh.easypanel.host/api/account/authentication',
      data: {
        'name': 'Test User',
        'email': 'testuserdio12345@example.com',
        'password': encrypted.base64,
        'gender': 0,
        'mission': 'Test mission',
        'mainSlogan': 'Test slogan'
      },
    );
    print('Dio Status: ${response.statusCode}');
    print('Dio Response: ${response.data}');
  } on DioException catch (e) {
    print('Dio Error Status: ${e.response?.statusCode}');
    print('Dio Error Data: ${e.response?.data}');
    print('Dio Error Message: ${e.message}');
  } catch (e) {
    print('General Error: $e');
  }
}
