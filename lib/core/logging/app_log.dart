import 'dart:async';
import 'dart:developer' as developer;

import 'package:logging/logging.dart';

/// App-wide logger, configured like MAUI Serilog in `MauiProgram.SetupSerilog`:
/// debug writes to the platform log (NSLog / logcat via [developer.log]);
/// release posts Error+ to `/api/logs` (same as MAUI `LogEventLevel.Error`).
class AppLog {
  AppLog._();

  static final Logger _logger = Logger('Principles');
  static StreamSubscription<LogRecord>? _subscription;

  /// Matches MAUI release sink minimum: Serilog `LogEventLevel.Error`.
  static const Level releaseMinimumLevel = Level.SEVERE;

  static Logger forScope(String name) => Logger('Principles.$name');

  static Future<void> setup({
    bool debug = true,
    void Function(LogRecord record)? releaseSink,
  }) async {
    hierarchicalLoggingEnabled = true;
    Logger.root.level = Level.INFO;

    await _subscription?.cancel();
    _subscription = Logger.root.onRecord.listen((record) {
      if (debug || releaseSink == null) {
        _writeToDeveloperLog(record);
      } else if (record.level >= releaseMinimumLevel) {
        releaseSink(record);
      }
    });
  }

  static void info(String message) => _logger.info(message);

  static void warning(String message) => _logger.warning(message);

  static void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);

  static void fatal(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.shout(message, error, stackTrace);

  static void _writeToDeveloperLog(LogRecord record) {
    developer.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  }
}
