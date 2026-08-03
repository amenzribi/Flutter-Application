/// Day-key formatting shared by the prayer log, schedule cache, and streak
/// algorithms.
abstract final class PrayerDayKey {
  /// Legacy `dayKey(d)`: local `yyyy-MM-dd`, zero-padded, defaulting to
  /// `DateTime.now()`. Deliberately **not** UTC — the legacy client always
  /// keys by the device's local wall-clock date.
  static String dayKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${d.year}-${pad(d.month)}-${pad(d.day)}';
  }
}
