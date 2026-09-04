enum SyncRunStatus {
  succeeded,
  skippedAlreadyRunning,
  skippedNoAuth,
  skippedNoInternet,
  skippedBackendUnavailable,
  skippedThrottled,
  skippedLocalOnly,
  failedAuthentication,
  failed,
}

class SyncRunResult {
  const SyncRunResult({
    required this.status,
    this.lastSuccessfulSyncAt,
    this.lastFailedSyncAt,
    this.error,
  });

  final SyncRunStatus status;
  final DateTime? lastSuccessfulSyncAt;
  final DateTime? lastFailedSyncAt;
  final Object? error;

  bool get isAuthenticationFailure =>
      status == SyncRunStatus.failedAuthentication;
}
