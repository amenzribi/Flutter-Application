/// Lifecycle of the on-device ↔ Firestore user-state synchronization.
///
/// See `docs/migration-analysis/FLUTTER_USER_STATE.md` § Sync strategy.
enum SyncStatus {
  /// Controller constructed; no auth user resolved yet.
  initial,

  /// Reading the SharedPreferences snapshot for the signed-in uid.
  loadingLocal,

  /// Local snapshot ready; waiting on the first Firestore read.
  loadingRemote,

  /// Local and remote reconciled; no pending local edits.
  ready,

  /// A local change is queued to be pushed (debounce window running).
  syncing,

  /// Last push/pull round-trip completed successfully.
  synced,

  /// Remote read/write failed or was skipped (e.g. offline, unverified
  /// email); local state remains authoritative and usable.
  offline,

  /// Unexpected failure while syncing.
  error,
}
