import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart';

void main() async {
  const _firstKey = 'yX7g53NL7X)xjV7#6DP+ipK5n)@9)_r!';
  const _secondKey = 'M%m5Vy9R(_k74t^M';

  final key = Key.fromUtf8(_firstKey);
  final iv = IV.fromUtf8(_secondKey);
  final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
  final encrypted = encrypter.encrypt('MyPassword123!', iv: iv);

  final client = HttpClient();
  final request = await client.postUrl(Uri.parse('https://principles-server.ckwavh.easypanel.host/api/account/authentication'));
  request.headers.set('content-type', 'application/json');
  request.add(utf8.encode(json.encode({
    'name': 'Test User',
    'email': 'testuser12345@example.com',
    'password': encrypted.base64,
    'gender': 0,
    'mission': 'Test mission',
    'mainSlogan': 'Test slogan'
  })));

  final response = await request.close();
  final responseBody = await response.transform(utf8.decoder).join();
  print('Status: ${response.statusCode}');
  print('Response: $responseBody');
}
