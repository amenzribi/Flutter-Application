import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/home/domain/services/day_part.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/daily_prayer_schedule.dart';
import 'package:barakah40_flutter/features/prayer/domain/entities/prayer_name.dart';
import 'package:barakah40_flutter/features/tree/domain/tree_growth_service.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';

void main() {
  final now = DateTime(2026, 10, 11, 13, 0);
  const today = '2026-10-11';
  const yesterday = '2026-10-10';

  Map<String, bool> prayed(int n) => {
    for (final p in PrayerName.values.take(n)) p.key: true,
  };

  UserAppState state({
    Map<String, dynamic> log = const {},
    int challengeDays = 0,
    Map<String, dynamic>? tree,
    Map<String, dynamic>? activity,
    Map<String, String>? times,
  }) => UserAppState.fromJson({
    'completed': List.generate(40, (i) => i < challengeDays),
    'prayer': {
      'log': log,
      'times': ?times,
      if (times != null) 'timesDate': today,
    },
    'tree': ?tree,
    'activity': ?activity,
  });

  group('points and stages', () {
    test('every source counts with the legacy weights and caps', () {
      final s = UserAppState.fromJson({
        'completed': List.generate(40, (i) => i < 2),
        'prayer': {
          'log': {today: prayed(5)},
        },
        'lastAyah': 143,
        'adhkarCount': {'morning': 60, 'evening': 40},
        'tasbeeh': {'count': 5000},
      });
      // 50 prayer + 30 days + 20 reading + 40 adhkar + 90 tasbih (capped).
      expect(TreeGrowthService.computePoints(s), 230);
    });

    test('thresholds map to the 20 stages', () {
      expect(TreeGrowthService.stageForPoints(0), 0);
      expect(TreeGrowthService.stageForPoints(4), 0);
      expect(TreeGrowthService.stageForPoints(5), 1);
      expect(TreeGrowthService.stageForPoints(611), 18);
      expect(TreeGrowthService.stageForPoints(612), 19);
      expect(TreeGrowthService.stageForPoints(99999), 19);
    });

    test('next-stage percent', () {
      expect(TreeGrowthService.nextPercent(0), 0);
      expect(TreeGrowthService.nextPercent(8), 43);
      expect(TreeGrowthService.nextPercent(612), 0);
    });
  });

  group('resolve', () {
    test('a first resolve shows the earned stage directly', () {
      final r = TreeGrowthService.resolve(state(log: {today: prayed(5)}), now);
      expect(r.display.stage, 5); // 50 points
      expect(r.display.healthy, isTrue);
      expect(r.display.imageAsset, endsWith('grow6.webp'));
      expect(r.updatedTree, isNotNull);
    });

    test('growth is capped at one stage a day', () {
      final s = state(
        log: {today: prayed(2), yesterday: prayed(3)},
        tree: {'shownStage': 1, 'stageDay': today, 'grownToday': 0},
      );
      final first = TreeGrowthService.resolve(s, now);
      expect(first.display.stage, 2);

      final again = TreeGrowthService.resolve(
        s.copyWithExtra('tree', first.updatedTree),
        now,
      );
      expect(again.display.stage, 2);
      expect(again.updatedTree, isNull, reason: 'nothing new to save');
    });

    test('a very active day allows two stages', () {
      final s = state(
        log: {today: prayed(4), yesterday: prayed(5)},
        tree: {'shownStage': 1, 'stageDay': today, 'grownToday': 0},
      );
      expect(TreeGrowthService.resolve(s, now).display.stage, 3);
    });

    test('the daily allowance resets on a new day', () {
      final s = state(
        log: {today: prayed(1), yesterday: prayed(5)},
        tree: {'shownStage': 2, 'stageDay': yesterday, 'grownToday': 1},
      );
      expect(TreeGrowthService.resolve(s, now).display.stage, 3);
    });

    test('a whole day without activity turns it into a dry seed', () {
      final s = state(
        log: {'2026-10-08': prayed(5)},
        tree: {'shownStage': 5, 'stageDay': yesterday, 'grownToday': 0},
      );
      final d = TreeGrowthService.resolve(s, now).display;
      expect(d.dormant, isTrue);
      expect(d.stage, 0);
      expect(d.healthy, isFalse);
      expect(d.imageAsset, endsWith('wilt1.webp'));
      expect(d.hint, contains('بذرةً يابسة'));
    });

    test('activity today wakes a dormant tree and it regrows', () {
      final s = state(
        log: {'2026-10-08': prayed(5)},
        activity: {
          today: {'read': true},
        },
        tree: {
          'shownStage': 0,
          'stageDay': today,
          'grownToday': 0,
          'dormant': true,
        },
      );
      final d = TreeGrowthService.resolve(s, now).display;
      expect(d.dormant, isFalse);
      expect(d.stage, 1);
      expect(d.healthy, isTrue);
    });

    test('a missed prayer window wilts it without losing the stage', () {
      final times = {
        'fajr': '05:10',
        'dhuhr': '12:30',
        'asr': '15:45',
        'maghrib': '18:20',
        'isha': '19:40',
      };
      final tree = {'shownStage': 3, 'stageDay': today, 'grownToday': 0};
      final missed = state(
        log: {yesterday: prayed(5)},
        activity: {
          today: {'read': true},
        },
        times: times,
        tree: tree,
      );
      final wilted = TreeGrowthService.resolve(missed, now).display;
      expect(wilted.healthy, isFalse);
      expect(wilted.stage, greaterThanOrEqualTo(3));
      expect(wilted.hint, contains('صلاة فائتة'));

      final done = state(
        log: {
          yesterday: prayed(5),
          today: {'fajr': true},
        },
        times: times,
        tree: tree,
      );
      expect(TreeGrowthService.resolve(done, now).display.healthy, isTrue);
    });

    test('without today\'s prayer times the tree never wilts', () {
      expect(TreeGrowthService.prayerWiltNow(state(), now), isFalse);
    });
  });

  test('recordActivity flags today and refreshes lastActive', () {
    final s = TreeGrowthService.recordActivity(
      state(),
      TreeActivity.adhkar,
      now,
    );
    expect(s.extraMap('activity')![today], {'adhkar': true});
    expect(s.extraMap('tree')!['lastActive'], now.millisecondsSinceEpoch);
    expect(TreeGrowthService.dayHasActivity(s, today), isTrue);
  });

  group('DayPart', () {
    test('follows today\'s prayer times when known', () {
      const schedule = DailyPrayerSchedule(
        dayKey: today,
        times: {
          PrayerName.fajr: '05:10',
          PrayerName.dhuhr: '12:30',
          PrayerName.asr: '15:45',
          PrayerName.maghrib: '18:20',
          PrayerName.isha: '19:40',
        },
      );
      DayPart at(int h, int m) =>
          DayPart.of(DateTime(2026, 10, 11, h, m), schedule: schedule);
      expect(at(4, 0), DayPart.night);
      expect(at(5, 30), DayPart.fajr);
      expect(at(9, 0), DayPart.morning);
      expect(at(13, 0), DayPart.dhuhr);
      expect(at(16, 0), DayPart.asr);
      expect(at(19, 0), DayPart.maghrib);
      expect(at(21, 0), DayPart.night);
    });

    test('falls back to fixed hours', () {
      expect(DayPart.of(DateTime(2026, 1, 1, 5)), DayPart.fajr);
      expect(DayPart.of(DateTime(2026, 1, 1, 12)), DayPart.dhuhr);
      expect(DayPart.of(DateTime(2026, 1, 1, 23)), DayPart.night);
      expect(
        DayPart.maghrib.backgroundAsset,
        'assets/images/bg/bg_maghrib.webp',
      );
    });
  });
}
