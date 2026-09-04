import 'dart:math';

class SyncRetryConfig {
  const SyncRetryConfig({
    this.maxRetryAttempts = 3,
    this.baseDelay = const Duration(minutes: 1),
    this.maxDelay = const Duration(hours: 1),
    this.backoffMultiplier = 2.0,
    this.jitterRange = const Duration(seconds: 30),
    Random? random,
  }) : _random = random;

  final int maxRetryAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final Duration jitterRange;
  final Random? _random;

  DateTime nextRetryAt(int retryCount, {DateTime? now, double? jitterFraction}) {
    var delay = baseDelay;
    for (var i = 0; i < retryCount; i++) {
      final nextTicks = (delay.inMicroseconds * backoffMultiplier).round();
      delay = Duration(microseconds: nextTicks);
      if (delay > maxDelay) {
        delay = maxDelay;
        break;
      }
    }

    final fraction = jitterFraction ?? (_random ?? Random()).nextDouble();
    final jitter = Duration(
      microseconds: (jitterRange.inMicroseconds * fraction).round(),
    );
    return (now ?? DateTime.now().toUtc()).add(delay + jitter);
  }
}
