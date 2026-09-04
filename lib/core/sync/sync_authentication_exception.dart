class SyncAuthenticationException implements Exception {
  SyncAuthenticationException([this.message = 'SyncPingUnauthorized']);

  final String message;

  @override
  String toString() => message;
}
