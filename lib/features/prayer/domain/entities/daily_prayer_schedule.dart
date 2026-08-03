import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_time.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/prayer_settings.dart';

/// A resolved set of the day's five prayer times, city/method context
/// included (legacy `(P.timesDate===k&&P.times)?P.times:{}`).
class DailyPrayerSchedule {
  const DailyPrayerSchedule({
    required this.dayKey,
    this.times = const {},
    this.city = '',
    this.country = '',
    this.method = 5,
  });

  /// `yyyy-MM-dd` this schedule is valid for (`PrayerDayKey.dayKey`).
  final String dayKey;

  /// Cleaned `HH:MM` strings keyed by prayer, only for prayers with a known
  /// time.
  final Map<PrayerName, String> times;
  final String city;
  final String country;
  final int method;

  /// Whether Fajr (the legacy same-day-cache sentinel) is known — mirrors
  /// legacy's `P.times && P.times.fajr` freshness check.
  bool get hasFajr => (times[PrayerName.fajr] ?? '').isNotEmpty;

  bool get isEmpty => times.isEmpty;

  /// Resolves each of the five prayers to a [PrayerTime] for [day] (usually
  /// the same calendar day [dayKey] refers to).
  List<PrayerTime> prayerTimesFor(DateTime day) {
    return [
      for (final name in PrayerName.values)
        PrayerTime.forDay(name, times[name], day),
    ];
  }

  /// Builds a schedule for [dayKey] from [settings], but only surfaces
  /// [PrayerSettings.times] when [PrayerSettings.timesDate] actually matches
  /// [dayKey] — otherwise the cache is stale (or from a prior day) and this
  /// returns an empty schedule rather than showing yesterday's times.
  factory DailyPrayerSchedule.fromSettings(
    PrayerSettings settings,
    String dayKey,
  ) {
    final matchesToday = settings.timesDate == dayKey;
    final times = <PrayerName, String>{};
    if (matchesToday) {
      for (final name in PrayerName.values) {
        final raw = settings.times[name.key];
        if (raw is String && raw.isNotEmpty) {
          times[name] = raw;
        }
      }
    }
    return DailyPrayerSchedule(
      dayKey: dayKey,
      times: times,
      city: settings.city,
      country: settings.country,
      method: settings.method,
    );
  }
}
