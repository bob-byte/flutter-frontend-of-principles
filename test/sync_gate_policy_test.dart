import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/core/sync/sync_gate_policy.dart';

void main() {
  final now = DateTime.utc(2026, 9, 9, 12);

  test('null since requires SyncGate (full bootstrap)', () {
    expect(requiresSyncGate(null, now: now), isTrue);
  });

  test('since younger than 20 days skips SyncGate', () {
    expect(
      requiresSyncGate(now.subtract(const Duration(days: 19)), now: now),
      isFalse,
    );
    expect(
      requiresSyncGate(now.subtract(const Duration(days: 1)), now: now),
      isFalse,
    );
  });

  test('since exactly 20 days old requires SyncGate', () {
    expect(
      requiresSyncGate(now.subtract(const Duration(days: 20)), now: now),
      isTrue,
    );
  });

  test('since older than 20 days requires SyncGate', () {
    expect(
      requiresSyncGate(now.subtract(const Duration(days: 21)), now: now),
      isTrue,
    );
    expect(
      requiresSyncGate(now.subtract(const Duration(days: 100)), now: now),
      isTrue,
    );
  });
}
