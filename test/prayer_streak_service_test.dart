import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/prayer/domain/services/prayer_day_key.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_streak_service.dart';

void main() {
  const full = {
    'fajr': true,
    'dhuhr': true,
    'asr': true,
    'maghrib': true,
    'isha': true,
  };
  const partial = {'fajr': true, 'dhuhr': true};

  group('PrayerStreakService.isFull', () {
    test('true only when all five prayers are marked', () {
      expect(PrayerStreakService.isFull(full), isTrue);
      expect(PrayerStreakService.isFull(partial), isFalse);
      expect(PrayerStreakService.isFull(const {}), isFalse);
    });
  });

  group('PrayerStreakService.currentStreak', () {
    test('counts consecutive full days ending today', () {
      final now = DateTime(2026, 8, 4);
      final log = {
        PrayerDayKey.dayKey(now): full,
        PrayerDayKey.dayKey(now.subtract(const Duration(days: 1))): full,
        PrayerDayKey.dayKey(now.subtract(const Duration(days: 2))): partial,
      };
      expect(PrayerStreakService.currentStreak(log, now: now), 2);
    });

    test('still counts yesterday onward when today is not full yet', () {
      final now = DateTime(2026, 8, 4);
      final log = {
        PrayerDayKey.dayKey(now.subtract(const Duration(days: 1))): full,
        PrayerDayKey.dayKey(now.subtract(const Duration(days: 2))): full,
      };
      expect(PrayerStreakService.currentStreak(log, now: now), 2);
    });

    test('zero when neither today nor yesterday is full', () {
      final now = DateTime(2026, 8, 4);
      expect(PrayerStreakService.currentStreak(const {}, now: now), 0);
    });

    test('a gap two days back stops the streak', () {
      final now = DateTime(2026, 8, 4);
      final log = {
        PrayerDayKey.dayKey(now): full,
        PrayerDayKey.dayKey(now.subtract(const Duration(days: 1))): full,
        // day -2 missing entirely (gap)
        PrayerDayKey.dayKey(now.subtract(const Duration(days: 3))): full,
      };
      expect(PrayerStreakService.currentStreak(log, now: now), 2);
    });
  });

  group('PrayerStreakService.longestStreak', () {
    test('finds the longest contiguous run of full days', () {
      final base = DateTime(2026, 8, 1);
      final log = <String, dynamic>{
        for (var i = 0; i < 3; i++)
          PrayerDayKey.dayKey(base.add(Duration(days: i))): full,
        PrayerDayKey.dayKey(base.add(const Duration(days: 5))): full,
        PrayerDayKey.dayKey(base.add(const Duration(days: 6))): full,
      };
      expect(PrayerStreakService.longestStreak(log), 3);
    });

    test('zero when no day is full', () {
      expect(PrayerStreakService.longestStreak({'2026-08-01': partial}), 0);
    });

    test('ignores non-full days interspersed with full ones', () {
      final base = DateTime(2026, 8, 1);
      final log = {
        PrayerDayKey.dayKey(base): full,
        PrayerDayKey.dayKey(base.add(const Duration(days: 1))): partial,
        PrayerDayKey.dayKey(base.add(const Duration(days: 2))): full,
      };
      expect(PrayerStreakService.longestStreak(log), 1);
    });
  });
}
