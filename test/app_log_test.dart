import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:principles_app/core/logging/app_log.dart';
import 'package:principles_app/core/logging/save_log_request.dart';

void main() {
  test('maps dart log levels to Serilog LogEventLevel names', () {
    expect(serilogLevelName(Level.FINEST), 'Verbose');
    expect(serilogLevelName(Level.CONFIG), 'Debug');
    expect(serilogLevelName(Level.INFO), 'Information');
    expect(serilogLevelName(Level.WARNING), 'Warning');
    expect(serilogLevelName(Level.SEVERE), 'Error');
    expect(serilogLevelName(Level.SHOUT), 'Fatal');
  });

  test('SaveLogRequest copies record message and device fields', () {
    const device = DeviceLogContext(
      deviceOs: 'iOS 18.0',
      deviceModelName: 'iPhone iPhone',
      deviceType: 'Physical',
      deviceManufacturer: 'Apple',
      appVersion: '1.0.0',
    );
    final record = LogRecord(Level.INFO, 'Dio Status: 200', 'Principles');

    final request = SaveLogRequest.fromRecord(record, device);

    expect(request.logType, 'Information');
    expect(request.logMessage, 'Dio Status: 200');
    expect(request.deviceOs, 'iOS 18.0');
    expect(request.appVersion, '1.0.0');
    expect(request.toJson()['logType'], 'Information');
  });

  test('release sink only receives Error+ like MAUI LogEventLevel.Error', () async {
    final posted = <Level>[];
    await AppLog.setup(
      debug: false,
      releaseSink: (record) => posted.add(record.level),
    );

    AppLog.info('ignored in release');
    AppLog.warning('ignored in release');
    AppLog.error('posted');
    AppLog.fatal('posted');

    await Future<void>.delayed(Duration.zero);

    expect(posted, [Level.SEVERE, Level.SHOUT]);
    expect(AppLog.releaseMinimumLevel, Level.SEVERE);
  });
}
