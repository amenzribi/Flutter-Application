import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/next_prayer_service.dart';

void main() {
  const times = {
    PrayerName.fajr: '04:30',
    PrayerName.dhuhr: '12:30',
    PrayerName.asr: '16:00',
    PrayerName.maghrib: '19:15',
    PrayerName.isha: '20:45',
  };

  group('NextPrayerService.nextPrayerInfo — ordering', () {
    test('returns the first prayer today whose time is still ahead', () {
      final now = DateTime(2026, 8, 4, 13, 0);
      final info = NextPrayerService.nextPrayerInfo(times, now);

      expect(info, isNotNull);
      expect(info!.name, PrayerName.asr);
      expect(info.time, '16:00');
      expect(info.at, DateTime(2026, 8, 4, 16, 0));
    });

    test('returns fajr itself when it is still ahead early in the day', () {
      final now = DateTime(2026, 8, 4, 2, 0);
      final info = NextPrayerService.nextPrayerInfo(times, now);

      expect(info!.name, PrayerName.fajr);
      expect(info.at, DateTime(2026, 8, 4, 4, 30));
    });

    test('skips a prayer with no known time and returns the next one', () {
      final sparseTimes = {PrayerName.dhuhr: '12:30', PrayerName.asr: '16:00'};
      final now = DateTime(2026, 8, 4, 5, 0);
      final info = NextPrayerService.nextPrayerInfo(sparseTimes, now);

      expect(info!.name, PrayerName.dhuhr);
    });
  });

  group('NextPrayerService.nextPrayerInfo — tomorrow fajr rollover', () {
    test('rolls over to tomorrow fajr once isha has passed', () {
      final now = DateTime(2026, 8, 4, 21, 30);
      final info = NextPrayerService.nextPrayerInfo(times, now);

      expect(info, isNotNull);
      expect(info!.name, PrayerName.fajr);
      expect(info.time, '04:30');
      expect(info.at, DateTime(2026, 8, 5, 4, 30));
    });

    test('returns null for the rollover when fajr itself has no time', () {
      final noFajr = {PrayerName.isha: '20:45'};
      final now = DateTime(2026, 8, 4, 23, 0);
      final info = NextPrayerService.nextPrayerInfo(noFajr, now);

      expect(info, isNull);
    });
  });

  group('NextPrayerService.nextPrayerInfo — missing times', () {
    test('returns null when there are no times at all', () {
      expect(
        NextPrayerService.nextPrayerInfo(const {}, DateTime.now()),
        isNull,
      );
    });

    test('ignores a malformed time string and continues to the next', () {
      final malformed = {
        PrayerName.dhuhr: 'not-a-time',
        PrayerName.asr: '16:00',
      };
      final now = DateTime(2026, 8, 4, 5, 0);
      final info = NextPrayerService.nextPrayerInfo(malformed, now);

      expect(info!.name, PrayerName.asr);
    });
  });

  group('NextPrayerInfo.countdownAt', () {
    test('returns the remaining duration before the prayer time', () {
      final info = NextPrayerInfo(
        name: PrayerName.dhuhr,
        time: '12:30',
        at: DateTime(2026, 8, 4, 12, 30),
      );
      final countdown = info.countdownAt(DateTime(2026, 8, 4, 12, 0));
      expect(countdown, const Duration(minutes: 30));
    });

    test('clamps to zero once the prayer time has passed', () {
      final info = NextPrayerInfo(
        name: PrayerName.dhuhr,
        time: '12:00',
        at: DateTime(2026, 8, 4, 12, 0),
      );
      final countdown = info.countdownAt(DateTime(2026, 8, 4, 12, 5));
      expect(countdown, Duration.zero);
    });
  });
}
