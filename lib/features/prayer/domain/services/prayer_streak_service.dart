import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_day_key.dart';

/// Pure port of legacy `isFull`/`currentStreak`/`longestStreak`, operating
/// on the raw `S.prayer.log` shape (`Map<dayKey, Map<prayerKey, bool>>`).
abstract final class PrayerStreakService {
  /// A day record is "full" only when all five prayers are marked true
  /// (legacy `PRAYERS.every(p=>rec[p[0]])`).
  static bool isFull(Map<String, dynamic> record) {
    return PrayerName.values.every((name) => record[name.key] == true);
  }

  /// Consecutive full days ending today (or yesterday, if today isn't full
  /// yet — legacy never breaks the streak just because today is still in
  /// progress).
  static int currentStreak(Map<String, dynamic> log, {DateTime? now}) {
    var day = now ?? DateTime.now();
    if (!isFull(_recordFor(log, day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (isFull(_recordFor(log, day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Longest run of consecutive full days anywhere in [log] (legacy sorts
  /// full day-keys and scans for `+1 day` runs).
  static int longestStreak(Map<String, dynamic> log) {
    final fullDays =
        log.entries
            .where((entry) => isFull(_asRecord(entry.value)))
            .map((entry) => entry.key)
            .toList()
          ..sort();

    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final key in fullDays) {
      final current = _parseDayKey(key);
      if (current == null) continue;
      if (previous != null && current.difference(previous).inDays == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
      previous = current;
    }
    return best;
  }

  static Map<String, dynamic> _recordFor(
    Map<String, dynamic> log,
    DateTime day,
  ) {
    return _asRecord(log[PrayerDayKey.dayKey(day)]);
  }

  static Map<String, dynamic> _asRecord(Object? value) {
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), v));
    }
    return const {};
  }

  static DateTime? _parseDayKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }
}
