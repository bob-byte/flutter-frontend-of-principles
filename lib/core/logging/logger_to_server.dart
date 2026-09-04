import 'dart:async';
import 'dart:developer' as developer;

import 'package:logging/logging.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../storage/secure_store.dart';
import 'save_log_request.dart';

/// Release sink equivalent of MAUI `LoggerToServer`.
class LoggerToServer {
  LoggerToServer({
    required ApiClient apiClient,
    required DeviceLogContext context,
  }) : _apiClient = apiClient,
       _context = context;

  static Future<LoggerToServer> create({
    required SecureStore secureStore,
  }) async {
    return LoggerToServer(
      apiClient: ApiClient(secureStore),
      context: await DeviceLogContext.capture(),
    );
  }

  final ApiClient _apiClient;
  final DeviceLogContext _context;

  void emit(LogRecord record) {
    unawaited(_post(record));
  }

  Future<void> _post(LogRecord record) async {
    try {
      await _apiClient.post(
        ApiEndpoints.logs,
        data: SaveLogRequest.fromRecord(record, _context).toJson(),
      );
    } catch (error) {
      developer.log(
        'Cannot post client log on the server: $error',
        name: 'LoggerToServer',
      );
    }
  }
}
