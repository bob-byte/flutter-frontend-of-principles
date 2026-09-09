/// How stale [lastSuccessfulSyncAt] must be before SyncGate blocks the shell.
///
/// A recent cursor uses `/sync/changes` in the background; a missing cursor
/// (full bootstrap) or one older than this still shows the loading gate.
const kSyncGateStaleSince = Duration(days: 20);

/// Whether MainShell should cover the UI with [SyncGateView].
///
/// [since] is the cursor that would be sent as `/sync/changes?since=`
/// (`null` → full `GET /sync/bootstrap`).
bool requiresSyncGate(DateTime? since, {DateTime? now}) {
  if (since == null) return true;
  final clock = (now ?? DateTime.now()).toUtc();
  return clock.difference(since.toUtc()) >= kSyncGateStaleSince;
}
