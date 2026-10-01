enum SyncTrigger {
  startup,
  authCompleted,
  resume,
  connectivityRestored,

  /// Silent push: another device changed or deleted tasks/habits.
  remotePush,
}
