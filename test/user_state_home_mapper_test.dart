import 'package:flutter_test/flutter_test.dart';

import 'package:barakah40_flutter/features/home/domain/services/home_progress_mapper.dart';
import 'package:barakah40_flutter/features/user_state/domain/entities/user_app_state.dart';

void main() {
  group('HomeProgressMapper — empty state', () {
    test(
      'defaults map to an entirely empty HomeProgress (no invented data)',
      () {
        final progress = HomeProgressMapper.map(UserAppState.defaults());

        expect(progress.hasStreak, isFalse);
        expect(progress.hasLastReading, isFalse);
        expect(progress.hasPrayerSummary, isFalse);
        expect(progress.hasChallenge, isFalse);
        expect(progress.hasTree, isFalse);
        expect(progress.hasQuranProgress, isFalse);
        expect(progress.hasAdhkar, isFalse);
      },
    );
  });

  group('HomeProgressMapper — real completed data', () {
    test('challengeDay = count of completed=true days', () {
      final completed = List<bool>.filled(40, false)
        ..[0] = true
        ..[1] = true
        ..[2] = true;
      final state = UserAppState.defaults().copyWith(completed: completed);

      final progress = HomeProgressMapper.map(state);
      expect(progress.hasChallenge, isTrue);
      expect(progress.challengeDay, 3);
    });

    test(
      'all-false completed reports no challenge (does not invent day 0)',
      () {
        final state = UserAppState.defaults();
        final progress = HomeProgressMapper.map(state);
        expect(progress.hasChallenge, isFalse);
        expect(progress.challengeDay, isNull);
      },
    );

    test('lastAyah maps to a reading label and a Quran completion percent', () {
      final state = UserAppState.defaults().copyWith(lastAyah: 143);
      final progress = HomeProgressMapper.map(state);

      expect(progress.hasLastReading, isTrue);
      expect(progress.lastReadingLabel, contains('143'));
      expect(progress.hasQuranProgress, isTrue);
      expect(progress.quranPercent, closeTo(143 / 286 * 100, 0.001));
    });

    test('adhkarCount presence flags morning/evening independently', () {
      final state = UserAppState.defaults().copyWith(
        adhkarCount: {'morning_0': 3},
      );
      final progress = HomeProgressMapper.map(state);

      expect(progress.adhkarMorningDone, isTrue);
      expect(progress.adhkarEveningDone, isNull);
      expect(progress.hasAdhkar, isTrue);
    });

    test('tree extra maps to a stage label when present', () {
      final state = UserAppState.defaults().copyWithExtra('tree', {
        'shownStage': 4,
      });
      final progress = HomeProgressMapper.map(state);

      expect(progress.hasTree, isTrue);
      expect(progress.treeStageLabel, isNotNull);
    });

    test('tree extra without a numeric shownStage yields no tree label', () {
      final state = UserAppState.defaults().copyWithExtra('tree', {
        'stageDay': '2026-08-03',
      });
      final progress = HomeProgressMapper.map(state);
      expect(progress.hasTree, isFalse);
    });

    test('prayer summary only appears when today has a log entry', () {
      final noEntry = HomeProgressMapper.map(UserAppState.defaults());
      expect(noEntry.hasPrayerSummary, isFalse);

      final today = _todayKey();
      final withEntry = UserAppState.defaults().copyWith(
        prayer: UserAppState.defaults().prayer.copyWith(
          log: {
            today: {'fajr': true, 'dhuhr': true, 'asr': false},
          },
        ),
      );
      final progress = HomeProgressMapper.map(withEntry);
      expect(progress.hasPrayerSummary, isTrue);
      expect(progress.prayerCompletedToday, 2);
      expect(progress.prayerTotalToday, 5);
    });

    test('never invents a streak (no legacy algorithm confirmed)', () {
      final state = UserAppState.defaults().copyWith(
        completed: List<bool>.filled(40, false)..[0] = true,
      );
      final progress = HomeProgressMapper.map(state);
      expect(progress.streakDays, isNull);
      expect(progress.hasStreak, isFalse);
    });
  });

  group(
    'HomeProgressMapper — completedChallengeDays / currentChallengeDay',
    () {
      test('never-started, nothing done: both fields are null', () {
        final progress = HomeProgressMapper.map(UserAppState.defaults());
        expect(progress.completedChallengeDays, isNull);
        expect(progress.currentChallengeDay, isNull);
      });

      test(
        'started but nothing completed yet: current day is 1, completed is 0',
        () {
          final state = UserAppState.defaults().copyWith(started: 1000);
          final progress = HomeProgressMapper.map(state);

          expect(progress.completedChallengeDays, 0);
          expect(progress.currentChallengeDay, 1);
        },
      );

      test(
        'a contiguous prefix of completed days advances the current day',
        () {
          final completed = List<bool>.filled(40, false)
            ..[0] = true
            ..[1] = true
            ..[2] = true;
          final state = UserAppState.defaults().copyWith(completed: completed);
          final progress = HomeProgressMapper.map(state);

          expect(progress.completedChallengeDays, 3);
          expect(progress.currentChallengeDay, 4); // first false index (3) + 1
        },
      );

      test('a non-contiguous completed day still reports the count done, but '
          'the current day points at the first incomplete day', () {
        final completed = List<bool>.filled(40, false)..[5] = true;
        final state = UserAppState.defaults().copyWith(completed: completed);
        final progress = HomeProgressMapper.map(state);

        expect(progress.completedChallengeDays, 1);
        expect(progress.currentChallengeDay, 1); // day 0 is still incomplete
      });

      test(
        'all 40 days complete: currentChallengeDay is null, completed is 40',
        () {
          final state = UserAppState.defaults().copyWith(
            completed: List<bool>.filled(40, true),
          );
          final progress = HomeProgressMapper.map(state);

          expect(progress.completedChallengeDays, 40);
          expect(progress.currentChallengeDay, isNull);
        },
      );
    },
  );
}

String _todayKey() {
  final now = DateTime.now();
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${now.year}-${pad(now.month)}-${pad(now.day)}';
}
