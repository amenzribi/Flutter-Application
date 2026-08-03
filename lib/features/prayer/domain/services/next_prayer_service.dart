import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';

/// The next upcoming prayer resolved from today's times (legacy
/// `nextPrayerInfo()`'s return shape `{key,name,at,time}`).
class NextPrayerInfo {
  const NextPrayerInfo({
    required this.name,
    required this.time,
    required this.at,
  });

  final PrayerName name;

  /// Cleaned `HH:MM` string.
  final String time;

  /// The concrete moment this prayer occurs (today, or tomorrow for the
  /// post-Isha Fajr rollover).
  final DateTime at;

  /// Remaining time until [at] from [now], clamped to zero once passed
  /// (legacy `Math.max(0,info.at-new Date())`).
  Duration countdownAt(DateTime now) {
    final diff = at.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }
}

/// Pure port of legacy `nextPrayerInfo()`.
abstract final class NextPrayerService {
  /// Given today's [times] (only prayers with a known `HH:MM` string need be
  /// present) and the current moment [now], returns the next prayer that
  /// hasn't happened yet today, in fajr→isha order.
  ///
  /// If every prayer today has already passed, rolls over to **tomorrow's**
  /// Fajr (legacy behavior — it re-uses today's Fajr string on the
  /// assumption Fajr's `HH:MM` doesn't meaningfully change day-to-day).
  /// Returns `null` when there isn't even a Fajr time to fall back on.
  static NextPrayerInfo? nextPrayerInfo(
    Map<PrayerName, String> times,
    DateTime now,
  ) {
    for (final name in PrayerName.values) {
      final time = times[name];
      if (time == null || time.isEmpty) continue;
      final at = _atTimeOnDay(time, now);
      if (at == null) continue;
      if (at.isAfter(now)) {
        return NextPrayerInfo(name: name, time: time, at: at);
      }
    }

    final fajr = times[PrayerName.fajr];
    if (fajr == null || fajr.isEmpty) return null;
    final tomorrow = now.add(const Duration(days: 1));
    final at = _atTimeOnDay(fajr, tomorrow);
    if (at == null) return null;
    return NextPrayerInfo(name: PrayerName.fajr, time: fajr, at: at);
  }

  static DateTime? _atTimeOnDay(String hhmm, DateTime day) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }
}
