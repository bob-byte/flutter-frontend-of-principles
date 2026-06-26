import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  try {
    final response = await dio.get(
      'https://principles-server.ckwavh.easypanel.host/api/account/code',
      queryParameters: {'emailWhereSendCode': 'testuserdio12345@example.com'},
    );
    print('Code: ${response.statusCode}');
    print('Data: ${response.data}');
  } on DioException catch (e) {
    print('Dio Error: ${e.response?.statusCode}');
    print('Response: ${e.response?.data}');
  } catch (e) {
    print('Error: $e');
  }
}
