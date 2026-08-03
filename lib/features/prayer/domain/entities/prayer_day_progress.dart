import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';

/// A single day's five-prayer completion summary (legacy `dayCount`/`isFull`).
class PrayerDayProgress {
  const PrayerDayProgress({this.flags = const {}});

  /// Per-prayer completion flags. A missing entry means "not completed",
  /// same as legacy's `!!rec[key]` on an absent key.
  final Map<PrayerName, bool> flags;

  static const int total = 5;

  static const empty = PrayerDayProgress();

  int get completedCount => PrayerName.values.where(isCompleted).length;

  bool get isFull => PrayerName.values.every(isCompleted);

  bool isCompleted(PrayerName name) => flags[name] == true;

  /// Builds from a raw legacy day record (`S.prayer.log[dayKey]`), a
  /// string-keyed map such as `{fajr: true, dhuhr: false}`.
  factory PrayerDayProgress.fromRecord(Map<String, dynamic> record) {
    final flags = <PrayerName, bool>{
      for (final name in PrayerName.values) name: record[name.key] == true,
    };
    return PrayerDayProgress(flags: flags);
  }
}
