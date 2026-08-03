/// UI state for the prayer schedule fetch pipeline
/// ([PrayerScheduleController]).
enum PrayerSyncState {
  /// A fetch (cache read, city fetch, or GPS lookup) is in progress.
  loading,

  /// A schedule for today is available (from cache or a fresh fetch).
  ready,

  /// A network fetch failed (e.g. no connectivity); a cached/prior schedule
  /// may still be shown alongside a retry action.
  offline,

  /// A fetch completed but returned no usable data (e.g. unknown city).
  error,

  /// Location permission was denied (or permanently denied).
  permissionDenied,

  /// No city is configured and location isn't available yet — prompt for
  /// manual city entry.
  needsCity,
}
