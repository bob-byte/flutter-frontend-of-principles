import 'package:dio/dio.dart';

import '../../services/dialog_service.dart';

/// HTTP 404 / 503 — MAUI maps both to [LocStrings.ServerTechnicalWorkIsInProgress].
class ServerTechnicalWorkException implements Exception {
  const ServerTechnicalWorkException({this.statusCode});

  factory ServerTechnicalWorkException.from(Object error) {
    return ServerTechnicalWorkException(statusCode: httpStatusOf(error));
  }

  final int? statusCode;

  @override
  String toString() => 'ServerTechnicalWorkException(statusCode: $statusCode)';
}

int? httpStatusOf(Object? error) {
  if (error is ServerTechnicalWorkException) return error.statusCode;
  if (error is DioException) return error.response?.statusCode;
  return null;
}

bool isServerTechnicalWorkStatus(int? status) => status == 404 || status == 503;

/// True when the API is gone or in maintenance (NOT FOUND / Service Unavailable).
bool isServerTechnicalWork(Object? error) {
  if (error == null) return false;
  if (error is ServerTechnicalWorkException) return true;
  return isServerTechnicalWorkStatus(httpStatusOf(error));
}

/// Retry loop for actions that cannot work offline (Helper, recommendations,
/// first post-sign-in bootstrap). Other HTTP errors are rethrown.
class ServerRequiredRetry {
  ServerRequiredRetry({DialogService? dialogs, Future<bool> Function()? prompt})
    : _dialogs = dialogs ?? DialogService(),
      _prompt = prompt;

  final DialogService _dialogs;
  final Future<bool> Function()? _prompt;

  Future<bool> offerRetry() async {
    final prompt = _prompt;
    if (prompt != null) return prompt();
    try {
      return await _dialogs.showServerTechnicalWorkRetry();
    } on StateError {
      // Navigator or l10n not attached (tests / early startup).
      return false;
    }
  }

  /// Returns the action result, or `null` if the user cancels after 404/503.
  Future<T?> run<T>(Future<T> Function() action) async {
    while (true) {
      try {
        return await action();
      } catch (e) {
        if (!isServerTechnicalWork(e)) rethrow;
        if (!await offerRetry()) return null;
      }
    }
  }
}
