import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Payload for `POST /api/logs`, matching MAUI `SaveLogRequest`.
class SaveLogRequest {
  const SaveLogRequest({
    required this.deviceOs,
    required this.deviceModelName,
    required this.deviceType,
    required this.deviceManufacturer,
    required this.appVersion,
    required this.logType,
    required this.logMessage,
    this.stackTrace,
  });

  factory SaveLogRequest.fromRecord(LogRecord record, DeviceLogContext device) {
    return SaveLogRequest(
      deviceOs: device.deviceOs,
      deviceModelName: device.deviceModelName,
      deviceType: device.deviceType,
      deviceManufacturer: device.deviceManufacturer,
      appVersion: device.appVersion,
      logType: serilogLevelName(record.level),
      logMessage: record.message,
      stackTrace: _stackTraceOf(record),
    );
  }

  final String deviceOs;
  final String deviceModelName;
  final String deviceType;
  final String deviceManufacturer;
  final String appVersion;
  final String logType;
  final String logMessage;
  final String? stackTrace;

  Map<String, dynamic> toJson() => {
    'deviceOs': deviceOs,
    'deviceModelName': deviceModelName,
    'deviceType': deviceType,
    'deviceManufacturer': deviceManufacturer,
    'appVersion': appVersion,
    'logType': logType,
    'logMessage': logMessage,
    'stackTrace': stackTrace,
  };
}

class DeviceLogContext {
  const DeviceLogContext({
    required this.deviceOs,
    required this.deviceModelName,
    required this.deviceType,
    required this.deviceManufacturer,
    required this.appVersion,
  });

  final String deviceOs;
  final String deviceModelName;
  final String deviceType;
  final String deviceManufacturer;
  final String appVersion;

  /// Same device fields MAUI sends in `CreateSaveLogRequest`.
  static Future<DeviceLogContext> capture() async {
    var appVersion = 'unknown';
    try {
      appVersion = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // Tests and some platforms may not provide package metadata.
    }

    try {
      return await _fromDeviceInfo(appVersion);
    } catch (_) {
      return DeviceLogContext(
        deviceOs: defaultTargetPlatform.name,
        deviceModelName: 'unknown',
        deviceType: 'Unknown',
        deviceManufacturer: 'unknown',
        appVersion: appVersion,
      );
    }
  }

  static Future<DeviceLogContext> _fromDeviceInfo(String appVersion) async {
    final plugin = DeviceInfoPlugin();

    if (kIsWeb) {
      final info = await plugin.webBrowserInfo;
      return DeviceLogContext(
        deviceOs: '${info.browserName.name} ${info.appVersion ?? ''}'.trim(),
        deviceModelName: info.platform ?? 'web',
        deviceType: 'Unknown',
        deviceManufacturer: info.vendor ?? 'unknown',
        appVersion: appVersion,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final info = await plugin.androidInfo;
        return DeviceLogContext(
          deviceOs: 'Android ${info.version.release}',
          deviceModelName: '${info.name} ${info.model}',
          deviceType: info.isPhysicalDevice ? 'Physical' : 'Virtual',
          deviceManufacturer: info.manufacturer,
          appVersion: appVersion,
        );
      case TargetPlatform.iOS:
        final info = await plugin.iosInfo;
        return DeviceLogContext(
          deviceOs: '${info.systemName} ${info.systemVersion}',
          deviceModelName: '${info.name} ${info.model}',
          deviceType: info.isPhysicalDevice ? 'Physical' : 'Virtual',
          deviceManufacturer: 'Apple',
          appVersion: appVersion,
        );
      case TargetPlatform.macOS:
        final info = await plugin.macOsInfo;
        return DeviceLogContext(
          deviceOs:
              'macOS ${info.majorVersion}.${info.minorVersion}.${info.patchVersion}',
          deviceModelName: '${info.computerName} ${info.model}',
          deviceType: 'Physical',
          deviceManufacturer: 'Apple',
          appVersion: appVersion,
        );
      case TargetPlatform.windows:
        final info = await plugin.windowsInfo;
        return DeviceLogContext(
          deviceOs:
              'Windows ${info.majorVersion}.${info.minorVersion}.${info.buildNumber}',
          deviceModelName: '${info.computerName} ${info.productName}',
          deviceType: 'Physical',
          deviceManufacturer: 'unknown',
          appVersion: appVersion,
        );
      case TargetPlatform.linux:
        final info = await plugin.linuxInfo;
        return DeviceLogContext(
          deviceOs: info.prettyName,
          deviceModelName: info.name,
          deviceType: 'Physical',
          deviceManufacturer: 'unknown',
          appVersion: appVersion,
        );
      default:
        return DeviceLogContext(
          deviceOs: defaultTargetPlatform.name,
          deviceModelName: 'unknown',
          deviceType: 'Unknown',
          deviceManufacturer: 'unknown',
          appVersion: appVersion,
        );
    }
  }
}

/// Backend `LogController` parses `LogType` as Serilog `LogEventLevel`.
String serilogLevelName(Level level) {
  if (level >= Level.SHOUT) return 'Fatal';
  if (level >= Level.SEVERE) return 'Error';
  if (level >= Level.WARNING) return 'Warning';
  if (level >= Level.INFO) return 'Information';
  if (level >= Level.CONFIG) return 'Debug';
  return 'Verbose';
}

String? _stackTraceOf(LogRecord record) {
  if (record.stackTrace != null) {
    return record.stackTrace.toString();
  }
  if (record.error != null) {
    return record.error.toString();
  }
  return null;
}
