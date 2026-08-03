import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/home/domain/services/home_progress_mapper.dart';
import 'package:barakah40_flutter/features/prayer/domain/services/prayer_day_key.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/prayer_settings.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';

void main() {
  group('HomeProgressMapper — prayer (empty state)', () {
    test('no schedule and no log means no next prayer or completion label', () {
      final progress = HomeProgressMapper.map(UserAppState.defaults());

      expect(progress.hasNextPrayer, isFalse);
      expect(progress.nextPrayerName, isNull);
      expect(progress.nextPrayerTime, isNull);
      expect(progress.nextPrayerAt, isNull);
      expect(progress.lastCompletedPrayerLabel, isNull);
      expect(progress.prayerLocationLabel, isNull);
    });
  });

  group('HomeProgressMapper — next prayer', () {
    test('a valid schedule for today maps to the next upcoming prayer', () {
      final now = DateTime(2026, 8, 4, 10, 0);
      final today = PrayerDayKey.dayKey(now);
      final state = UserAppState.defaults().copyWith(
        prayer: const PrayerSettings().copyWith(
          timesDate: today,
          times: const {
            'fajr': '04:00',
            'dhuhr': '12:30',
            'asr': '15:45',
            'maghrib': '19:00',
            'isha': '20:30',
          },
          city: 'طرابلس',
        ),
      );

      final progress = HomeProgressMapper.map(state, now: now);

      expect(progress.hasNextPrayer, isTrue);
      expect(progress.nextPrayerName, 'الظهر');
      expect(progress.nextPrayerTime, '12:30');
      expect(progress.nextPrayerAt, DateTime(2026, 8, 4, 12, 30));
      expect(progress.prayerLocationLabel, 'طرابلس');
    });

    test('a schedule from a stale day (timesDate mismatch) is ignored', () {
      final now = DateTime(2026, 8, 4, 10, 0);
      final state = UserAppState.defaults().copyWith(
        prayer: const PrayerSettings().copyWith(
          timesDate: '2026-08-01',
          times: const {'fajr': '04:00'},
        ),
      );

      final progress = HomeProgressMapper.map(state, now: now);
      expect(progress.hasNextPrayer, isFalse);
    });
  });

  group('HomeProgressMapper — lastCompletedPrayerLabel', () {
    test('is the last true prayer walking fajr..isha', () {
      final today = PrayerDayKey.dayKey();
      final state = UserAppState.defaults().copyWith(
        prayer: const PrayerSettings().copyWith(
          log: {
            today: {
              'fajr': true,
              'dhuhr': true,
              'asr': false,
              'maghrib': false,
              'isha': false,
            },
          },
        ),
      );

      expect(HomeProgressMapper.map(state).lastCompletedPrayerLabel, 'الظهر');
    });

    test('is null when nothing is marked today', () {
      expect(
        HomeProgressMapper.map(
          UserAppState.defaults(),
        ).lastCompletedPrayerLabel,
        isNull,
      );
    });
  });

  group('HomeProgressMapper — prayerLocationLabel', () {
    test('reflects the saved city, null when unset', () {
      final withCity = UserAppState.defaults().copyWith(
        prayer: const PrayerSettings().copyWith(city: 'بنغازي'),
      );
      expect(HomeProgressMapper.map(withCity).prayerLocationLabel, 'بنغازي');
      expect(
        HomeProgressMapper.map(UserAppState.defaults()).prayerLocationLabel,
        isNull,
      );
    });
  });
}
