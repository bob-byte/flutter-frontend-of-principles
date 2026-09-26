/// How stale [lastSuccessfulSyncAt] must be before SyncGate blocks the shell.
///
/// A recent cursor uses `/sync/changes` in the background; a missing cursor
/// (full bootstrap) or one older than this still shows the loading gate.
/// Interactive sign-in always covers via [shouldShowSyncGate] / `forceSyncGate`.
const kSyncGateStaleSince = Duration(days: 20);

/// Whether a sync cursor alone requires covering the shell with SyncGate.
///
/// [since] is the cursor that would be sent as `/sync/changes?since=`
/// (`null` → full `GET /sync/bootstrap`).
bool requiresSyncGate(DateTime? since, {DateTime? now}) {
  if (since == null) return true;
  final clock = (now ?? DateTime.now()).toUtc();
  return clock.difference(since.toUtc()) >= kSyncGateStaleSince;
}

/// Whether MainShell should show [SyncGateView] while session data loads.
///
/// [forceSyncGate] is set after interactive sign-in (`LaunchDataLoader.reset`)
/// so re-login always shows the loading page even when a recent cursor exists.
/// Cold start still skips the gate for a fresh `since` (under 20 days).
bool shouldShowSyncGate({
  required bool isSyncGateComplete,
  required bool forceSyncGate,
  required DateTime? since,
  DateTime? now,
}) {
  if (isSyncGateComplete) return false;
  if (forceSyncGate) return true;
  return requiresSyncGate(since, now: now);
}
