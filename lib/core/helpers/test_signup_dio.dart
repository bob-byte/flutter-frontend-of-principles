import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart';

import '../logging/app_log.dart';

void main() async {
  await AppLog.setup();

  const firstKey = 'yX7g53NL7X)xjV7#6DP+ipK5n)@9)_r!';
  const secondKey = 'M%m5Vy9R(_k74t^M';

  final key = Key.fromUtf8(firstKey);
  final iv = IV.fromUtf8(secondKey);
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
        'mainSlogan': 'Test slogan',
      },
    );
    AppLog.info('Dio Status: ${response.statusCode}');
    AppLog.info('Dio Response: ${response.data}');
  } on DioException catch (e) {
    AppLog.error('Dio Error Status: ${e.response?.statusCode}', e);
    AppLog.error('Dio Error Data: ${e.response?.data}', e);
    AppLog.error('Dio Error Message: ${e.message}', e);
  } catch (e, stackTrace) {
    AppLog.error('General Error: $e', e, stackTrace);
  }
}
