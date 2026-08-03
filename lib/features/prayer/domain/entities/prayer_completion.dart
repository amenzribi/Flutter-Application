import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';

/// A single prayer's completion flag for one day (`S.prayer.log[dayKey][key]`).
class PrayerCompletion {
  const PrayerCompletion({
    required this.dayKey,
    required this.name,
    required this.completed,
  });

  final String dayKey;
  final PrayerName name;
  final bool completed;
}
